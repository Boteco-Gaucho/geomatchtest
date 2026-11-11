// service-worker.js

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const path = data.path || data.url || "/";
  const targetUrl = new URL(path, self.location.origin).href;

  console.log('[SW] notificationclick — URL de destino:', targetUrl);

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      console.log('[SW] Abas abertas encontradas:', windowClients.length);

      const existing = windowClients.find(c => c.url.startsWith(self.location.origin));

      if (existing) {
        console.log('[SW] Navegando aba existente:', existing.url, '→', targetUrl);
        return existing.navigate(targetUrl)
          .then((navigated) => (navigated || existing).focus())
          .catch(() => {
            // navigate() rejeita em clientes não controlados no Chrome — abre nova aba
            console.log('[SW] navigate() falhou — abrindo nova janela');
            return clients.openWindow(targetUrl);
          });
      }

      console.log('[SW] Nenhuma aba aberta — abrindo nova janela');
      return clients.openWindow(targetUrl);
    })
  );
});

self.addEventListener("push", (event) => {
  let payload = { title: "GeoMatch", body: "Nova notificação!", data: { path: "/" } };

  if (event.data) {
    try {
      payload = event.data.json();
    } catch (e) {
      payload.body = event.data.text();
    }
  }

  const path = (payload.data && payload.data.path) || "/";

  event.waitUntil((async () => {
    // Ponte nativa Android (WebView)
    if (typeof Android !== 'undefined' && Android.mostrarNotificacao) {
      Android.mostrarNotificacao(payload.title, payload.body, path);
      return;
    }

    // Sempre exibe a notificação do sistema — obrigatório para iOS em segundo plano.
    // Mesmo com o app aberto, o banner deve aparecer; o postMessage atualiza a UI em paralelo.
    await self.registration.showNotification(payload.title, {
      body:      payload.body,
      icon:      '/icon.png',
      badge:     '/icon.png',  // ícone monocromático na barra de status do Android/iOS
      data:      { path, app: (payload.data && payload.data.app) || 'GeoMatch' },
      tag:       payload.tag || `chat-${path}`,
      renotify:  true,
      silent:    false,
    });

    // Avisa abas abertas para atualizar a UI sem recarregar
    const allClients = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    allClients.forEach(client => {
      client.postMessage({ type: 'PUSH_RECEIVED', title: payload.title, body: payload.body, path });
    });
  })());
});