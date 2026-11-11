// app/javascript/push_notifications.js

// 1. Função para lidar com mensagens vindas do Service Worker (Ponte Android)
const setupServiceWorkerMessageListener = () => {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'PUSH_RECEIVED') {
        console.log("Mensagem Push recebida do Worker:", event.data);

        // Garante que nunca envie 'undefined' para o Java convertendo para String
        const titulo = String(event.data.title || "GeoMatch");
        const msg    = String(event.data.body  || "Nova mensagem recebida");
        const rota   = String(event.data.path  || "/");

        // Verifica se a ponte nativa Android existe (WebView)
        if (typeof Android !== 'undefined' && Android.mostrarNotificacao) {
          Android.mostrarNotificacao(titulo, msg, rota);
          console.log("Notificação enviada para a ponte nativa Android.");
        } else {
          // Fallback Web: exibe via browser notification API
          if (Notification.permission === 'granted') {
            navigator.serviceWorker.ready.then(reg => {
              reg.showNotification(titulo, {
                body: msg,
                icon: '/assets/logo.png',
                badge: '/assets/logo.png',
                data: { path: rota }
              });
            });
          } else {
            console.warn("[GeoMatch] Push recebido mas permissão de notificação não concedida.");
          }
        }
      }
    });
  }
};

// 2. Inicialização Principal
document.addEventListener("turbo:load", () => {
  console.log("Iniciando verificação de Service Worker...");
  setupServiceWorkerMessageListener();

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
      .then(async (registration) => {
        // Aguarda o Service Worker estar pronto/ativo
        await navigator.serviceWorker.ready;
        console.log("Service Worker está pronto.");

        // Tenta buscar o PushManager com 2 segundos de delay para a WebView carregar tudo
        setTimeout(() => {
          const pushManager = registration.pushManager || window.PushManager;

          if (pushManager) {
            console.log("PushManager encontrado com sucesso!");
            subscribeUserToPush(registration);
          } else {
            // Se cair aqui, vamos tentar um método de emergência:
            console.warn("PushManager não veio no window, tentando via registration direto...");
            if (registration.pushManager) {
               subscribeUserToPush(registration);
            } else {
               console.error("ERRO FATAL: A WebView desativou o PushManager completamente.");
            }
          }
        }, 2000);
      });
  }
});

// 3. Funções Auxiliares de Inscrição
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

function subscribeUserToPush(registration) {
  const applicationServerKeyElement = document.querySelector('meta[name="vapid-public-key"]');
  if (!applicationServerKeyElement) return;

  const notificationApi = window.Notification || self.Notification;

  if (notificationApi) {
    notificationApi.requestPermission().then(permission => {
      console.log("Status da permissão:", permission);
      if (permission === "granted") {
        registration.pushManager.getSubscription().then(existingSubscription => {
          if (existingSubscription) return existingSubscription;

          return registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(applicationServerKeyElement.content)
          });
        })
        .then(subscription => {
          sendSubscriptionToBackend(subscription);
        })
        .catch(error => console.error("Erro na inscrição Push:", error));
      }
    });
  } else {
    console.warn("API de Notificação não encontrada neste ambiente.");
  }
}

function sendSubscriptionToBackend(subscription) {
  const subscriptionData = subscription.toJSON();
  const csrfToken = document.querySelector("meta[name='csrf-token']").content;

  fetch("/push_subscriptions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken
    },
    body: JSON.stringify({
      push_subscription: {
        endpoint: subscriptionData.endpoint,
        p256dh: subscriptionData.keys.p256dh,
        auth: subscriptionData.keys.auth
      }
    })
  });
}

// 4. Lógica de Desinscrição (Opcional)
function unsubscribeUserFromPush() {
  navigator.serviceWorker.ready.then(registration => {
    registration.pushManager.getSubscription().then(subscription => {
      if (subscription) {
        subscription.unsubscribe().then(successful => {
          console.log("Usuário desinscrito com sucesso.");
          sendUnsubscriptionToBackend(subscription.endpoint);
        }).catch(error => {
          console.error("Falha ao desinscrever o usuário:", error);
        });
      }
    });
  });
}

function sendUnsubscriptionToBackend(endpoint) {
  const csrfToken = document.querySelector("meta[name='csrf-token']").content;

  fetch("/push_subscriptions", {
    method: "DELETE",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken
    },
    body: JSON.stringify({ endpoint: endpoint })
  })
  .then(response => {
    if (response.ok) console.log("Inscrição removida do backend.");
  })
  .catch(error => console.error("Erro ao remover inscrição:", error));
}