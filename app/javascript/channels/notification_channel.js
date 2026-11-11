import consumer from "./consumer"

consumer.subscriptions.create("NotificationChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
    console.log("Conectado ao NotificationChannel");
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    // Chamado quando há dados transmitidos pelo canal
    console.log("Notificação recebida:", data);
    
    // 1. Adiciona a nova notificação ao topo da lista (ex: em um dropdown)
    const notificationsList = document.getElementById("notifications-list");
    if (notificationsList) {
      notificationsList.insertAdjacentHTML('afterbegin', data.html);
    }
    
    // 2. Atualiza o contador de notificações não lidas (ex: um badge no ícone de sino)
    const unreadCount = document.getElementById("unread-notifications-count");
    if (unreadCount) {
      unreadCount.textContent = data.count;
      unreadCount.classList.remove('hidden'); // Garante que o badge seja visível
    }
    
    // Opcional: Exibir um toast ou alerta para o usuário
    alert(`Nova notificação: ${data.html.match(/<strong>(.*?)<\/strong>/)[1]} curtiu você!`);
  }
});
