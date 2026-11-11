// presence.js — Camada global de presença no mapa
//
// Este módulo é carregado no layout principal (autenticado) e vive durante toda
// a sessão do navegador. Ele mantém a subscrição ao MapChannel e um heartbeat
// de localização que continuam funcionando independentemente de qual aba o
// usuário esteja navegando. Assim, o marcador no mapa de outros usuários não
// some quando o usuário troca de tela.
//
// Arquitetura de colaboração com map_3d.js:
//   window.presenceSetLocation(lat, lng)  — chamado por map_3d.js com as coords
//   window.setMapRealtimeHandler(fn|null) — registra/limpa o handler de dados do canal
//
// Estratégias de keep-alive (Safari PWA apenas — não aplicadas no app nativo):
//   1. fetch keepalive    — heartbeat sobrevive ao unload/background
//   2. Beacon API         — envia última posição no momento em que a aba é ocultada

import consumer from "./channels/consumer";

// Detecta app nativo iOS (WkWebView com bridge Swift injetada).
// No app nativo o background location é gerido pela camada Swift via
// window.handleNativeLocationUpdate (live_location.js).
const isTurboNative = !!window.webkit?.messageHandlers?.locationHandler;

console.log(`[Presence] Módulo carregado. isTurboNative=${isTurboNative}`);

let _sub         = null;   // Subscrição única ao MapChannel para toda a sessão
let _interval    = null;   // Timer do heartbeat
let _beaconSetup = false;  // Guard: evita registar o visibilitychange mais de uma vez

// =============================================================================
//   API pública consumida por map_3d.js
// =============================================================================

window.presenceSetLocation = (lat, lng) => {
  window._presenceLat = lat;
  window._presenceLng = lng;
};

window.setMapRealtimeHandler = (fn) => {
  window._mapRealtimeHandler = (typeof fn === 'function') ? fn : null;
};

// =============================================================================
//   MapChannel — subscrição única por sessão
// =============================================================================

function ensureSubscribed() {
  if (_sub) return;

  _sub = consumer.subscriptions.create("MapChannel", {
    connected() {
      console.log('[Presence] MapChannel conectado globalmente');
      const lat  = window._presenceLat;
      const lng  = window._presenceLng;
      if (!lat || !lng) return;
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content ?? '';
      fetch('/users/update_location', {
        method:    'POST',
        keepalive: true,
        headers:   { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
        body:      JSON.stringify({ latitude: lat, longitude: lng })
      }).catch(() => {});
    },
    disconnected() {
      console.log('[Presence] MapChannel desconectado — ActionCable reconectará automaticamente');
    },
    received(data) {
      if (typeof window._mapRealtimeHandler === 'function') {
        window._mapRealtimeHandler(data);
      }
    }
  });
}

// =============================================================================
//   Heartbeat — 30s, com keepalive para sobreviver ao background no iOS Safari
// =============================================================================

function ensureHeartbeat() {
  if (_interval) return;

  _interval = setInterval(() => {
    const lat = window._presenceLat;
    const lng = window._presenceLng;
    const now = new Date().toISOString();

    console.log(`[Presence/Heartbeat] ⏱ ${now} | lat=${lat?.toFixed(5) ?? '—'} lng=${lng?.toFixed(5) ?? '—'}`);

    if (!lat || !lng) return;

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content ?? '';
    fetch('/users/update_location', {
      method:    'POST',
      keepalive: true,
      headers:   { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
      body:      JSON.stringify({ latitude: lat, longitude: lng })
    }).catch((err) => {
      console.warn(`[Presence/Heartbeat] fetch falhou: ${err.message}`);
    });
  }, 30_000);
}

// =============================================================================
//   Beacon API — envia última posição ao ocultar a aba (Safari apenas)
//
//   navigator.sendBeacon não suporta headers customizados. Para que o Rails
//   valide o CSRF token, enviamos o campo authenticity_token no corpo do
//   pedido como application/x-www-form-urlencoded. O Rails lê este campo a
//   partir de params[:authenticity_token] antes de processar a action.
// =============================================================================

function setupVisibilityBeacon() {
  if (isTurboNative || _beaconSetup) return;
  _beaconSetup = true;

  document.addEventListener('visibilitychange', () => {
    const state = document.visibilityState;
    console.log(`[Presence/Beacon] visibilitychange → state="${state}"`);

    if (state !== 'hidden') return;

    const lat = window._presenceLat;
    const lng = window._presenceLng;

    if (!lat || !lng) {
      console.warn('[Presence/Beacon] Beacon não enviado — lat/lng indisponível.');
      return;
    }

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content ?? '';
    const body = new URLSearchParams({
      authenticity_token: csrf,
      latitude:           lat,
      longitude:          lng
    });

    const accepted = navigator.sendBeacon(
      '/users/update_location',
      new Blob([body.toString()], { type: 'application/x-www-form-urlencoded' })
    );

    console.log(`[Presence/Beacon] sendBeacon(lat=${lat.toFixed(5)}, lng=${lng.toFixed(5)}) → ${accepted ? '✅ aceito' : '❌ rejeitado'}`);
  });

  console.log('[Presence/Beacon] Listener de visibilitychange registado.');
}

// =============================================================================
//   Ciclo de vida — Turbo
// =============================================================================

document.addEventListener('turbo:load', () => {
  if (!document.querySelector('meta[name="user-logged-in"]')) {
    teardown();
    return;
  }
  ensureSubscribed();
  ensureHeartbeat();
  setupVisibilityBeacon();
});

// Logout explícito: desmonta antes de a sessão ser destruída.
// O MapChannel#unsubscribed no servidor cuidará do broadcast "leave".
document.addEventListener('turbo:before-visit', (e) => {
  const url = e.detail?.url ?? '';
  if (/sign_out|logout/.test(url)) teardown();
});

function teardown() {
  if (_sub)      { _sub.unsubscribe();       _sub = null; }
  if (_interval) { clearInterval(_interval); _interval = null; }
  window._presenceLat        = null;
  window._presenceLng        = null;
  window._mapRealtimeHandler = null;
  // _beaconSetup não é resetado: o listener permanece registado mas
  // retorna imediatamente por lat/lng nulos enquanto o utilizador está deslogado.
  console.log('[Presence] teardown() executado — subscrição e heartbeat encerrados.');
}
