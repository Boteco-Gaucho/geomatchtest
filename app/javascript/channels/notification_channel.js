import consumer from "./consumer"

// Curtidas em tempo real (NotificationBroadcastJob): atualiza o número do rodapé
// (#likes-badge) e, se a pessoa está na aba Curtidas, recarrega a lista na hora.
// Carregado uma vez pelo application.js; a assinatura vale para todas as telas.
if (!window.__gmNotificationChannel) {
  window.__gmNotificationChannel = consumer.subscriptions.create("NotificationChannel", {
    received(data) {
      const count = Number(data.count) || 0
      document.querySelectorAll("#likes-badge").forEach((badge) => {
        badge.textContent = count > 99 ? "99+" : String(count)
        badge.hidden = count === 0
      })

      const onLikesPage = window.location.pathname.replace(/\/$/, "") === "/notifications"
      if (onLikesPage && data.kind !== "mimo_transaction" && document.visibilityState === "visible" && window.Turbo) {
        window.Turbo.visit(window.location.href, { action: "replace" })
      }
    }
  })
}
