import consumer from "./channels/consumer";

document.addEventListener('turbo:load', () => {
  const chatWindow = document.getElementById('chat-window');
  const messageInput = document.getElementById('message-input');
  const newMessageForm = document.getElementById('new-message-form');

  if (!chatWindow || !messageInput || !newMessageForm) return;

  // Este arquivo é carregado duas vezes na página (application.js e o include do chat):
  // só a primeira cópia liga esta conversa. Antes as duas ligavam — duas assinaturas do
  // canal, dois observadores de leitura. WeakSet: cada visita traz um #chat-window novo.
  window.__gmChatWired ||= new WeakSet();
  if (window.__gmChatWired.has(chatWindow)) return;
  window.__gmChatWired.add(chatWindow);

  const matchId = chatWindow.dataset.matchId;
  const currentUserId = parseInt(chatWindow.dataset.currentUserId, 10);
  const slideContainer = chatWindow.querySelector('.messages-slide-container');
  const typingIndicator = document.getElementById('typing-indicator');

  // Regras do menu da mensagem (as mesmas do servidor — ver Message)
  const EDIT_WINDOW_MS   = (parseInt(chatWindow.dataset.editWindow, 10) || 900) * 1000;
  const DELETE_WINDOW_MS = (parseInt(chatWindow.dataset.deleteWindow, 10) || 180) * 1000;
  const CHAT_CONTROLS    = chatWindow.dataset.chatControls === 'true';
  const GROUP_GAP_MS     = 5 * 60 * 1000; // mesmo intervalo do show.html.erb

  let typingTimer;
  let typingHideTimer;
  const TYPING_TIMEOUT = 3000;

  const csrfToken = () => document.querySelector('meta[name="csrf-token"]').content;

  // =======================================================
  //   INJECT OVERLAYS (apenas uma vez por turbo:load)
  // =======================================================
  injectContextOverlay();
  injectReportSheet();

  // Configura long press nas mensagens já presentes no HTML
  chatWindow.querySelectorAll('.message-row').forEach(setupLongPress);

  // =======================================================
  //   SUBSCRIPTION
  // =======================================================
  const matchChannel = consumer.subscriptions.create(
    { channel: "MatchChannel", match_id: matchId },
    {
      connected() {
        console.log("Conectado ao match", matchId);
        scrollToBottom();
        chatWindow.querySelectorAll('.message-row.received:not([data-status="read"])').forEach(row => readObserver.observe(row));
      },

      received(data) {
        // -------------------------
        //    INDICADOR DE DIGITAÇÃO
        // -------------------------
        if (Object.prototype.hasOwnProperty.call(data, "typing")) {
          if (data.user_id == currentUserId) return;
          updateTypingIndicator(data.typing === true);
          return;
        }

        // -------------------------
        //   ATUALIZAÇÃO DE STATUS
        // -------------------------
        if (data.action === 'status_update') {
          handleStatusUpdate(data);
          return;
        }

        // -------------------------
        //     NOVA MENSAGEM
        // -------------------------
        if (data.message) {
          if (data.message.sender_id !== currentUserId) updateTypingIndicator(false);
          else hideQuickReplies(); // a primeira mensagem saiu (deste ou de outro aparelho)
          appendMessageToDOM(data.message);

          if (data.message.sender_id !== currentUserId) {
            matchChannel.perform('mark_as_delivered', { message_id: data.message.id });
          }
          return;
        }

        // -------------------------
        //   MENSAGEM EDITADA
        // -------------------------
        if (data.edited_message) {
          applyEdit(data.edited_message);
          return;
        }

        // -------------------------
        //   MENSAGEM APAGADA (para todos)
        // -------------------------
        // -------------------------
        //   MATCH DESFEITO (pela outra pessoa): a conversa não existe mais
        // -------------------------
        if (data.unmatched) {
          if (data.user_id !== currentUserId) {
            showToast('Esta conversa não está mais disponível.', true);
            setTimeout(() => { window.Turbo ? Turbo.visit('/matches', { action: 'replace' }) : window.location.replace('/matches'); }, 1500);
          }
          return;
        }

        if (data.deleted_message_id) {
          removeMessageRow(data.deleted_message_id);
          markQuotesAsDeleted(data.deleted_message_id);
          return;
        }

        // -------------------------
        //   REAÇÃO ATUALIZADA
        // -------------------------
        if (data.reaction) {
          updateReactionDisplay(data.reaction);
          return;
        }
      },

      sendTypingStatus(isTyping) {
        this.perform("receive", { typing: isTyping });
      }
    }
  );

  // Saiu da conversa: fecha a assinatura (antes ficavam abertas uma por visita)
  document.addEventListener('turbo:visit', () => {
    readObserver.disconnect();
    matchChannel.unsubscribe();
  }, { once: true });

  // =======================================================
  //   ABRIU A CONVERSA — TUDO O QUE CHEGOU FICA LIDO
  //   O servidor já marca ao montar a página (MatchesController#show). Se ainda houver
  //   recebida sem "lida" (página do pré-carregamento do Turbo), confirma por HTTP — não
  //   depende do WebSocket nem de cada balão aparecer na tela.
  // =======================================================
  if (chatWindow.querySelector('.message-row.received:not([data-status="read"])') && chatWindow.dataset.readUrl) {
    fetch(chatWindow.dataset.readUrl, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' },
      keepalive: true
    })
    .then((response) => {
      if (response.ok) chatWindow.querySelectorAll('.message-row.received').forEach(row => { row.dataset.status = 'read'; });
    })
    .catch(() => {});
  }

  // =======================================================
  //   INTERSECTION OBSERVER — MARCAR MENSAGENS COMO LIDAS
  //   (as que chegam com a conversa aberta)
  // =======================================================
  const readObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const msgId = parseInt(entry.target.id.replace('msg-', ''), 10);
      matchChannel.perform('mark_as_read', { message_id: msgId });
      readObserver.unobserve(entry.target);
    });
  }, { root: chatWindow, threshold: 0.5 });

  // =======================================================
  //   MENU DOS TRÊS PONTINHOS
  //   Limpar conversa (só para mim) e Silenciar notificações
  // =======================================================
  const headerMenu = document.querySelector('[data-chat-menu-target="menu"]');
  const closeHeaderMenu = () => {
    if (!headerMenu) return;
    headerMenu.hidden = true;
    document.querySelector('[data-chat-menu-target="trigger"]')?.setAttribute('aria-expanded', 'false');
  };

  const clearBtn = document.getElementById('clear-chat-btn');
  if (clearBtn) {
    const clearForm = clearBtn.closest('form');

    clearForm.addEventListener('submit', (e) => {
      e.preventDefault();
      if (!window.confirm('Limpar a conversa? As mensagens somem só para você.')) return;

      fetch(clearForm.action, {
        method: "DELETE",
        headers: { "X-CSRF-Token": csrfToken(), "Accept": "application/json" }
      })
      .then(response => {
        if (response.ok) {
          // Mantém o começo da conversa (aviso de segurança + como vocês se conectaram)
          chatWindow.querySelectorAll('.message-row, .date-separator:not(.is-connection)').forEach(m => m.remove());
          cancelReply();
          closeHeaderMenu();
          showToast('Conversa limpa.');
        } else {
          showToast('Não foi possível limpar a conversa agora.', true);
        }
      })
      .catch(err => console.error("Erro ao limpar:", err));
    });
  }

  const muteBtn = document.getElementById('mute-chat-btn');
  if (muteBtn) {
    const muteForm = muteBtn.closest('form');

    muteForm.addEventListener('submit', (e) => {
      e.preventDefault();
      fetch(muteForm.action, {
        method: "PATCH",
        headers: { "X-CSRF-Token": csrfToken(), "Accept": "application/json" }
      })
      .then(response => response.ok ? response.json() : Promise.reject(response))
      .then(({ muted }) => {
        muteBtn.dataset.muted = String(muted);
        muteBtn.querySelector('.gm-mute-label').textContent = muted ? 'Ativar notificações' : 'Silenciar notificações';
        muteBtn.querySelector('.gm-icon-muted').hidden = !muted;
        muteBtn.querySelector('.gm-icon-unmuted').hidden = muted;
        closeHeaderMenu();
        showToast(muted ? 'Notificações silenciadas.' : 'Notificações ativadas.');
      })
      .catch(() => showToast('Não foi possível alterar as notificações agora.', true));
    });
  }

  // =======================================================
  //   INDICADOR DE DIGITAÇÃO (balão com três pontinhos)
  // =======================================================
  function updateTypingIndicator(isTyping) {
    if (!typingIndicator) return;

    clearTimeout(typingHideTimer);
    typingIndicator.hidden = !isTyping;
    if (isTyping) {
      scrollToBottom();
      // Se o "parou de digitar" não chegar (app fechado, rede), some sozinho
      typingHideTimer = setTimeout(() => { typingIndicator.hidden = true; }, 8000);
    }
  }

  // =======================================================
  //   CAPTURA DE "ESTÁ DIGITANDO"
  // =======================================================
  messageInput.addEventListener("input", () => {
    matchChannel.sendTypingStatus(true);
    clearTimeout(typingTimer);
    typingTimer = setTimeout(() => {
      matchChannel.sendTypingStatus(false);
    }, TYPING_TIMEOUT);
  });

  // =======================================================
  //   RESPONDER / EDITAR (barra acima do campo)
  //   Arrastar uma mensagem para a direita (ou "Responder" no toque longo)
  //   marca a mensagem; "Editar" usa a mesma barra e o mesmo campo.
  // =======================================================
  const otherUserName     = chatWindow.dataset.otherUserName || 'Usuário';
  const replyPreview      = document.getElementById('reply-preview');
  const replyPreviewName  = document.getElementById('reply-preview-name');
  const replyPreviewText  = document.getElementById('reply-preview-text');
  const replyPreviewClose = document.getElementById('reply-preview-close');
  let replyingTo = null; // id da mensagem que está sendo respondida
  let editingId  = null; // id da mensagem que está sendo editada

  function startReply(row) {
    const id = parseInt((row.id || '').replace('msg-', ''), 10);
    if (!id || !replyPreview) return;

    if (editingId) cancelEdit();
    replyingTo = id;
    replyPreviewName.textContent = row.classList.contains('sent') ? 'Você' : otherUserName;
    replyPreviewText.textContent = row.dataset.content || '';
    replyPreview.hidden = false;
    messageInput.focus();
  }

  function cancelReply() {
    replyingTo = null;
    if (replyPreview && !editingId) replyPreview.hidden = true;
  }

  function startEdit(row) {
    const id = parseInt((row.id || '').replace('msg-', ''), 10);
    if (!id || !replyPreview) return;

    cancelReply();
    editingId = id;
    replyPreviewName.textContent = 'Editando mensagem';
    replyPreviewText.textContent = row.dataset.content || '';
    replyPreview.hidden = false;
    messageInput.value = row.dataset.content || '';
    messageInput.focus();
  }

  function cancelEdit() {
    if (!editingId) return;
    editingId = null;
    messageInput.value = '';
    if (replyPreview) replyPreview.hidden = true;
  }

  if (replyPreviewClose) {
    // mousedown sem default: no desktop o campo não perde o foco ao fechar a barra
    replyPreviewClose.addEventListener('mousedown', (e) => e.preventDefault());
    replyPreviewClose.addEventListener('click', () => { editingId ? cancelEdit() : cancelReply(); });
  }

  // Citação dentro do balão (mesmo HTML que o show.html.erb desenha)
  function quoteHtml(quoted) {
    if (!quoted || !quoted.id) return '';
    const name = Number(quoted.sender_id) === currentUserId ? 'Você' : (quoted.sender_name || otherUserName);
    return `<button type="button" class="msg-quote" data-reply-to-id="${parseInt(quoted.id, 10)}">` +
             `<span class="msg-quote-name">${escapeHtml(name)}</span>` +
             `<span class="msg-quote-text">${escapeHtml(quoted.content)}</span>` +
           `</button>`;
  }

  // Tocar na citação: rola até a mensagem original e a destaca
  function jumpToMessage(id) {
    const target = document.getElementById(`msg-${parseInt(id, 10)}`);
    if (!target) return;

    const rowRect = target.getBoundingClientRect();
    const winRect = chatWindow.getBoundingClientRect();
    chatWindow.scrollBy({
      top: (rowRect.top - winRect.top) - (winRect.height - rowRect.height) / 2,
      behavior: 'smooth'
    });

    target.classList.remove('is-highlighted');
    void target.offsetWidth; // reinicia a animação num segundo toque seguido
    target.classList.add('is-highlighted');
    setTimeout(() => target.classList.remove('is-highlighted'), 1600);
  }

  // A mensagem citada foi apagada: a citação não pode continuar mostrando o texto
  function markQuotesAsDeleted(id) {
    const msgId = parseInt(id, 10);
    chatWindow.querySelectorAll(`.msg-quote[data-reply-to-id="${msgId}"]`).forEach((quote) => {
      quote.classList.add('is-deleted');
      const text = quote.querySelector('.msg-quote-text');
      if (text) text.textContent = 'Mensagem apagada';
    });
    if (replyingTo === msgId) cancelReply();
    if (editingId === msgId) cancelEdit();
  }

  // =======================================================
  //   RESPOSTAS RÁPIDAS E "+" (ENVIAR UM MIMO)
  // =======================================================
  // As sugestões são só para puxar assunto: saem depois da primeira mensagem enviada
  function hideQuickReplies() {
    const quickReplies = document.getElementById('chat-quick-replies');
    if (quickReplies) quickReplies.remove();
  }

  document.querySelectorAll('.chat-quick-reply').forEach((chip) => {
    chip.addEventListener('mousedown', (e) => e.preventDefault()); // não tira o foco do campo
    chip.addEventListener('click', () => {
      messageInput.value = chip.dataset.text || chip.textContent.trim();
      messageInput.focus();
    });
  });

  const plusBtn  = document.getElementById('chat-plus-btn');
  const plusMenu = document.getElementById('chat-plus-menu');
  if (plusBtn && plusMenu) {
    const closePlus = () => { plusMenu.hidden = true; plusBtn.setAttribute('aria-expanded', 'false'); };
    plusBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      const open = plusMenu.hidden;
      plusMenu.hidden = !open;
      plusBtn.setAttribute('aria-expanded', String(open));
    });
    document.addEventListener('click', (e) => { if (!plusMenu.hidden && !plusMenu.contains(e.target)) closePlus(); });
  }

  // =======================================================
  //   SUBMIT DA MENSAGEM
  //   (sem <form>: o envio é disparado pelo botão ou pelo Enter)
  // =======================================================
  const sendButton = document.getElementById('send-button');
  const messagesUrl = `${window.location.origin}/matches/${matchId}/messages`;

  function sendMessage() {
    const content = messageInput.value.trim();
    if (!content) return;
    if (editingId) { saveEdit(content); return; }

    const message = { content };
    if (replyingTo) message.reply_to_id = replyingTo;
    const repliedRow = replyingTo ? document.getElementById(`msg-${replyingTo}`) : null;

    messageInput.value = "";
    cancelReply();
    matchChannel.sendTypingStatus(false);

    // A mensagem só aparece quando o servidor a retransmite pelo ActionCable.
    // Se o envio falhar, devolve o texto (e a resposta marcada) e avisa — antes
    // ela simplesmente sumia, sem nenhum sinal para quem estava digitando.
    const restoreUnsent = () => {
      if (!messageInput.value) messageInput.value = content;
      if (repliedRow && repliedRow.isConnected && !replyingTo) startReply(repliedRow);
      showToast('Não foi possível enviar a mensagem. Tente novamente.', true);
    };

    fetch(messagesUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      body: JSON.stringify({ message }),
    })
    .then((response) => {
      if (!response.ok) {
        console.error("Erro ao enviar mensagem", response.status);
        restoreUnsent();
      } else {
        hideQuickReplies();
      }
    })
    .catch((error) => {
      console.error(error);
      restoreUnsent();
    });
  }

  // Salva a edição; o balão é atualizado pelo broadcast (edited_message)
  function saveEdit(content) {
    const id = editingId;
    const row = document.getElementById(`msg-${id}`);
    if (row && row.dataset.content === content) { cancelEdit(); return; }

    fetch(`${messagesUrl}/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken(), "Accept": "application/json" },
      body: JSON.stringify({ message: { content } }),
    })
    .then(async (response) => {
      if (response.ok) {
        applyEdit(await response.json());
        cancelEdit();
      } else {
        const data = await response.json().catch(() => ({}));
        showToast(data.error || 'Não foi possível editar a mensagem.', true);
      }
    })
    .catch(() => showToast('Não foi possível editar a mensagem.', true));
  }

  // Mesmo toast de shared/_flash.html.erb (fica acima do chat: z-index do container)
  function showToast(text, isError = false) {
    const container = document.getElementById("toast-container");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = `toast toast--${isError ? 'alert' : 'notice'}`;
    toast.setAttribute("data-controller", "toast");
    toast.setAttribute("role", "alert");
    toast.setAttribute("aria-live", "polite");
    toast.innerHTML =
      `<span class="toast__message"></span>` +
      `<button class="toast__close" data-action="toast#close" aria-label="Fechar">✕</button>`;
    toast.querySelector('.toast__message').textContent = text;
    container.prepend(toast);
  }

  if (sendButton) sendButton.addEventListener('click', sendMessage);

  messageInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    } else if (e.key === 'Escape' && (replyingTo || editingId)) {
      e.preventDefault();
      editingId ? cancelEdit() : cancelReply();
    }
  });

  // =======================================================
  //   APPEND NO DOM (mesmo HTML do show.html.erb)
  // =======================================================
  function appendMessageToDOM(message) {
    if (document.getElementById(`msg-${message.id}`)) return;

    const isSender = message.sender_id === currentUserId;
    const sentAt = message.created_at ? new Date(message.created_at) : new Date();
    const lastRow = lastMessageRow();

    // Dia novo (conversa aberta na virada da meia-noite, ou primeira mensagem
    // num dia diferente da conexão): separador "Hoje"
    const lastDate = lastRow ? new Date(lastRow.dataset.sentAt) : new Date(chatWindow.dataset.connectionDate || sentAt);
    if (!sameDay(lastDate, sentAt)) {
      const separator = document.createElement('div');
      separator.className = 'date-separator';
      separator.textContent = 'Hoje';
      insertInConversation(separator);
    }

    const el = document.createElement("div");
    el.className = `message message-row ${isSender ? "sent" : "received"} is-group-end`;
    el.id = `msg-${message.id}`;
    el.dataset.content = message.content || '';
    el.dataset.sentAt = sentAt.toISOString();
    el.dataset.status = message.status || 'sent';
    el.dataset.readAt = '';

    const statusHtml = isSender
      ? `<span class="message-status status-${message.status || 'sent'}" data-status-id="${message.id}"></span>`
      : '';
    el.innerHTML =
      `<div class="message-bubble">${quoteHtml(message.reply_to)}<span class="msg-text">${escapeHtml(message.content)}</span></div>` +
      `<div class="message-meta"><span class="message-time">${formatTime(message.created_at)}</span>${statusHtml}</div>` +
      `<span class="message-timestamp">${formatTime(message.created_at)}</span>`;

    // Mesma pessoa em menos de 5 min: o horário passa para o novo balão
    if (lastRow && lastRow.classList.contains(isSender ? 'sent' : 'received') &&
        sentAt - new Date(lastRow.dataset.sentAt) <= GROUP_GAP_MS && sameDay(new Date(lastRow.dataset.sentAt), sentAt)) {
      lastRow.classList.remove('is-group-end');
    }

    insertInConversation(el);

    // Configura long press na nova mensagem
    setupLongPress(el);

    if (!isSender) readObserver.observe(el);

    scrollToBottom();
  }

  function lastMessageRow() {
    const rows = chatWindow.querySelectorAll('.message-row');
    return rows[rows.length - 1] || null;
  }

  // Antes do balão de "digitando", que fica sempre por último
  function insertInConversation(el) {
    const target = slideContainer || chatWindow;
    if (typingIndicator && typingIndicator.parentNode === target) {
      target.insertBefore(el, typingIndicator);
    } else {
      target.appendChild(el);
    }
  }

  // Tirou um balão: quem ficou por último na sequência volta a mostrar o horário
  function removeMessageRow(id) {
    const el = document.getElementById(`msg-${parseInt(id, 10)}`);
    if (!el) return;

    const previous = el.previousElementSibling;
    const wasGroupEnd = el.classList.contains('is-group-end');
    el.remove();
    if (wasGroupEnd && previous && previous.classList.contains('message-row')) {
      previous.classList.add('is-group-end');
    }
  }

  // Mensagem editada (broadcast ou resposta do PATCH)
  function applyEdit(edited) {
    const row = document.getElementById(`msg-${parseInt(edited.id, 10)}`);
    if (!row) return;

    row.dataset.content = edited.content || '';
    const text = row.querySelector('.msg-text');
    if (text) text.textContent = edited.content || '';

    const meta = row.querySelector('.message-meta');
    if (meta && !meta.querySelector('.message-edited')) {
      const label = document.createElement('span');
      label.className = 'message-edited';
      label.textContent = 'editada';
      meta.querySelector('.message-time')?.after(label);
    }

    chatWindow.querySelectorAll(`.msg-quote[data-reply-to-id="${parseInt(edited.id, 10)}"] .msg-quote-text`)
      .forEach((quote) => { quote.textContent = edited.content || ''; });
  }

  // =======================================================
  //   LONG PRESS — DETECTAR PRESSIONAR E SEGURAR
  // =======================================================
  let longPressTimer = null;

  function setupLongPress(row) {
    // Evita dupla configuração
    if (row.dataset.lpSetup) return;
    row.dataset.lpSetup = "1";

    let startX, startY;

    row.addEventListener('touchstart', (e) => {
      e.preventDefault();
      e.stopPropagation();
      const touch = e.touches[0];
      startX = touch.clientX;
      startY = touch.clientY;
      longPressTimer = setTimeout(() => openContextMenu(row), 500);
    }, { passive: false });

    row.addEventListener('touchmove', (e) => {
      const touch = e.touches[0];
      const dx = Math.abs(touch.clientX - startX);
      const dy = Math.abs(touch.clientY - startY);
      if (dx > 10 || dy > 10) clearTimeout(longPressTimer);
    }, { passive: true });

    row.addEventListener('touchend',   () => clearTimeout(longPressTimer));
    row.addEventListener('touchcancel', () => clearTimeout(longPressTimer));

    // Computador: botão direito abre o mesmo menu
    row.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      openContextMenu(row);
    });
  }

  // =======================================================
  //   MENU DA MENSAGEM (segurar o balão)
  //   O balão aparece em foco no mesmo lugar, com o horário embaixo
  //   ("Lida às 13:05") e as ações; recebidas têm reações em cima.
  // =======================================================
  const QUICK_REACTIONS = ['👍', '❤️', '😂', '😮', '😢'];
  const MORE_REACTIONS  = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '😍', '🥰', '😘', '👏', '🎉',
                           '😅', '🤣', '😎', '🤔', '👀', '💯', '🙌', '😳', '😡', '💔', '✨', '🌹'];

  const ICONS = {
    reply:  '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/></svg>',
    copy:   '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/></svg>',
    edit:   '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>',
    trash:  '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M10 11v6M14 11v6"/></svg>',
    flag:   '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 22V4a1 1 0 0 1 1-1h11l-2 4.5 2 4.5H5"/></svg>',
    plus:   '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>'
  };

  function openContextMenu(row) {
    if (navigator.vibrate) navigator.vibrate(35);

    const overlay = document.getElementById('msg-context-overlay');
    const menu    = document.getElementById('msg-context-menu');
    const bubble  = row.querySelector('.message-bubble');
    if (!overlay || !menu || !bubble) return;

    const msgId   = row.id.replace('msg-', '');
    const isSent  = row.classList.contains('sent');
    const content = row.dataset.content || '';
    const sentAt  = new Date(row.dataset.sentAt || Date.now());
    const now     = Date.now();

    const canEdit = isSent && CHAT_CONTROLS && now - sentAt < EDIT_WINDOW_MS;
    const readAt  = row.dataset.readAt ? new Date(row.dataset.readAt) : null;
    const canDeleteForAll = isSent &&
      (row.dataset.status !== 'read' || (readAt && now - readAt < DELETE_WINDOW_MS));

    let html = '';

    // ----- RECEBIDAS: barra de reações -----
    if (!isSent) {
      html += `<div class="emoji-reaction-bar">` +
        QUICK_REACTIONS.map(emoji => `<button type="button" class="emoji-btn" data-emoji="${emoji}">${emoji}</button>`).join('') +
        `<button type="button" class="emoji-btn emoji-more" aria-label="Mais reações">${ICONS.plus}</button>` +
        `</div>`;
    }

    // ----- Balão em foco + horário -----
    html += `<div class="msg-context-bubble ${isSent ? 'is-sent' : 'is-received'}">${bubble.innerHTML}</div>`;
    html += `<div class="msg-context-meta">${contextMetaHtml(row, isSent, sentAt)}</div>`;

    // ----- Ações -----
    const actions = [];
    actions.push(['reply', 'Responder', ICONS.reply]);
    actions.push(['copy', 'Copiar', ICONS.copy]);
    if (canEdit) actions.push(['edit', 'Editar', ICONS.edit]);
    actions.push('separator');
    if (CHAT_CONTROLS) actions.push(['hide', 'Apagar para mim', ICONS.trash, 'danger']);
    if (isSent && canDeleteForAll) actions.push(['delete', 'Apagar para todos', ICONS.trash, 'danger is-strong']);
    if (!isSent) actions.push(['report', 'Denunciar mensagem', ICONS.flag, 'danger is-strong']);

    html += `<div class="msg-context-actions">` + actions.map(action => {
      if (action === 'separator') return `<div class="context-separator"></div>`;
      const [name, label, icon, extra] = action;
      return `<button type="button" class="context-action ${extra || ''}" data-action="${name}">${label}${icon}</button>`;
    }).join('') + `</div>`;

    menu.innerHTML = html;
    menu.className = `msg-context-menu ${isSent ? 'is-sent' : 'is-received'}`;
    overlay.classList.remove('hidden');

    // O balão em foco tem a mesma largura do original (quebra as linhas igual)
    const rect = bubble.getBoundingClientRect();
    const focused = menu.querySelector('.msg-context-bubble');
    focused.style.width = `${rect.width}px`;
    positionContextMenu(menu, rect, isSent);

    // Reações
    menu.querySelectorAll('.emoji-btn:not(.emoji-more)').forEach(btn => {
      btn.addEventListener('click', () => {
        sendReaction(msgId, btn.dataset.emoji);
        closeContextMenu();
      });
    });
    menu.querySelector('.emoji-more')?.addEventListener('click', () => expandReactions(menu, msgId, rect, isSent));

    // Ações
    menu.querySelectorAll('.context-action').forEach(btn => {
      btn.addEventListener('click', () => {
        closeContextMenu();
        switch (btn.dataset.action) {
          case 'reply':  startReply(row); break;
          case 'copy':   copyText(content); break;
          case 'edit':   startEdit(row); break;
          case 'hide':   hideMessage(msgId); break;
          case 'delete': deleteMessage(msgId); break;
          case 'report': openReportSheet(msgId, content); break;
        }
      });
    });

    // Fechar ao clicar no fundo
    document.getElementById('msg-context-backdrop').onclick = closeContextMenu;
  }

  // "Lida às 13:05 ✓✓" / "Entregue às 13:04 ✓✓" / "Enviada às 13:04 ✓" / "Recebida às 13:04"
  function contextMetaHtml(row, isSent, sentAt) {
    const sentTime = formatTime(sentAt.toISOString());
    if (!isSent) return `Recebida às ${sentTime}`;

    const status = row.dataset.status || 'sent';
    const icon = `<span class="message-status status-${status}"></span>`;
    if (status === 'read') {
      return row.dataset.readAt ? `Lida às ${formatTime(row.dataset.readAt)} ${icon}` : `Lida ${icon}`;
    }
    return `${status === 'delivered' ? 'Entregue' : 'Enviada'} às ${sentTime} ${icon}`;
  }

  // Alinha a pilha ao balão pressionado e a mantém inteira dentro da tela
  function positionContextMenu(menu, rect, isSent) {
    const margin = 12;
    const bar = menu.querySelector('.emoji-reaction-bar');
    const barOffset = bar ? bar.offsetHeight + 9 : 0;

    if (isSent) {
      menu.style.left = 'auto';
      menu.style.right = `${Math.max(margin, window.innerWidth - rect.right)}px`;
    } else {
      menu.style.right = 'auto';
      menu.style.left = `${Math.max(margin, rect.left)}px`;
    }

    const height = menu.offsetHeight;
    const maxTop = window.innerHeight - height - margin;
    menu.style.top = `${Math.max(margin, Math.min(rect.top - barOffset, maxTop))}px`;
  }

  // "+" da barra de reações: mostra mais emojis
  function expandReactions(menu, msgId, rect, isSent) {
    const bar = menu.querySelector('.emoji-reaction-bar');
    if (!bar) return;

    bar.classList.add('is-expanded');
    bar.innerHTML = MORE_REACTIONS.map(emoji => `<button type="button" class="emoji-btn" data-emoji="${emoji}">${emoji}</button>`).join('');
    bar.querySelectorAll('.emoji-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        sendReaction(msgId, btn.dataset.emoji);
        closeContextMenu();
      });
    });
    positionContextMenu(menu, rect, isSent);
  }

  function closeContextMenu() {
    const overlay = document.getElementById('msg-context-overlay');
    if (overlay) overlay.classList.add('hidden');
  }

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeContextMenu();
  });

  // =======================================================
  //   COPIAR
  // =======================================================
  function copyText(text) {
    const done = () => showToast('Mensagem copiada.');
    const fallback = () => {
      const area = document.createElement('textarea');
      area.value = text;
      area.setAttribute('readonly', '');
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.appendChild(area);
      area.select();
      try { document.execCommand('copy'); done(); } catch (_) { showToast('Não foi possível copiar.', true); }
      area.remove();
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback);
    } else {
      fallback();
    }
  }

  // =======================================================
  //   APAGAR PARA TODOS / APAGAR PARA MIM
  // =======================================================
  function deleteMessage(msgId) {
    fetch(`/matches/${matchId}/messages/${msgId}`, {
      method: 'DELETE',
      headers: { 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' }
    })
    .then(async (res) => {
      if (res.ok) {
        // Remove localmente (o ActionCable remove para a outra pessoa)
        removeMessageRow(msgId);
      } else {
        const data = await res.json().catch(() => ({}));
        showToast(data.error || 'Não foi possível apagar a mensagem.', true);
      }
    })
    .catch(err => console.error('Erro ao apagar mensagem:', err));
  }

  function hideMessage(msgId) {
    fetch(`/matches/${matchId}/messages/${msgId}/hide`, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' }
    })
    .then((res) => {
      if (res.ok) {
        removeMessageRow(msgId);
        if (replyingTo === parseInt(msgId, 10)) cancelReply();
      } else {
        showToast('Não foi possível apagar a mensagem.', true);
      }
    })
    .catch(err => console.error('Erro ao apagar mensagem:', err));
  }

  // =======================================================
  //   ENVIAR REAÇÃO
  // =======================================================
  function sendReaction(msgId, emoji) {
    fetch(`/matches/${matchId}/messages/${msgId}/react`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      },
      body: JSON.stringify({ emoji })
    })
    .catch(err => console.error('Erro ao enviar reação:', err));
  }

  // =======================================================
  //   EXIBIR REAÇÕES NO BALÃO
  // =======================================================
  function updateReactionDisplay(reaction) {
    const row = document.getElementById(`msg-${reaction.message_id}`);
    if (!row) return;

    let reactionBar = row.querySelector('.reaction-bar');

    const counts  = reaction.counts || {};
    const entries = Object.entries(counts);

    if (entries.length === 0) {
      if (reactionBar) reactionBar.remove();
      return;
    }

    const html = entries.map(([emoji, count]) =>
      `<span class="reaction-badge">${escapeHtml(emoji)}${count > 1 ? ` ${count}` : ''}</span>`
    ).join('');

    if (!reactionBar) {
      reactionBar = document.createElement('div');
      reactionBar.className = 'reaction-bar';
      row.querySelector('.message-bubble')?.after(reactionBar);
    }

    reactionBar.innerHTML = html;
  }

  // =======================================================
  //   INJETAR OVERLAY DE CONTEXTO
  // =======================================================
  function injectContextOverlay() {
    if (document.getElementById('msg-context-overlay')) return;
    const el = document.createElement('div');
    el.id = 'msg-context-overlay';
    el.className = 'msg-context-overlay hidden';
    el.innerHTML = `
      <div id="msg-context-backdrop" class="msg-context-backdrop"></div>
      <div id="msg-context-menu" class="msg-context-menu"></div>
    `;
    document.body.appendChild(el);
  }

  // =======================================================
  //   INJETAR BOTTOM SHEET DE DENÚNCIA
  // =======================================================
  function injectReportSheet() {
    if (document.getElementById('msg-report-sheet')) return;
    const el = document.createElement('div');
    el.id = 'msg-report-sheet';
    el.className = 'msg-report-sheet hidden';
    el.innerHTML = `
      <div class="msg-report-backdrop" id="msg-report-backdrop"></div>
      <div class="msg-report-body">
        <h3>Denunciar mensagem</h3>
        <p class="msg-report-preview"></p>
        <textarea id="msg-report-textarea" placeholder="Descreva o motivo da denúncia (opcional)..."></textarea>
        <div class="msg-report-actions">
          <button class="btn-cancel-report" id="msg-report-cancel">Cancelar</button>
          <button class="btn-submit-report" id="msg-report-submit">Denunciar</button>
        </div>
      </div>
    `;
    document.body.appendChild(el);

    document.getElementById('msg-report-backdrop').onclick = closeReportSheet;
    document.getElementById('msg-report-cancel').onclick   = closeReportSheet;
    document.getElementById('msg-report-submit').onclick   = submitReport;
  }

  function openReportSheet(msgId, content) {
    const sheet    = document.getElementById('msg-report-sheet');
    const preview  = sheet?.querySelector('.msg-report-preview');
    const textarea = document.getElementById('msg-report-textarea');
    if (!sheet) return;

    if (preview)  preview.textContent = content || '';
    if (textarea) textarea.value = '';
    sheet.dataset.msgId   = msgId;
    sheet.dataset.content = content || '';
    sheet.classList.remove('hidden');
  }

  function closeReportSheet() {
    const sheet = document.getElementById('msg-report-sheet');
    if (sheet) sheet.classList.add('hidden');
  }

  function submitReport() {
    const sheet    = document.getElementById('msg-report-sheet');
    const textarea = document.getElementById('msg-report-textarea');
    const msgId    = sheet?.dataset.msgId || '';
    const content  = sheet?.dataset.content || '';
    const extra    = textarea?.value.trim() || '';

    const description = `[Msg #${msgId}] "${content}"${extra ? ' — ' + extra : ''}`;

    fetch('/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      },
      body: JSON.stringify({ description })
    })
    .then(res => {
      if (res.ok || res.status === 201 || res.status === 204) {
        closeReportSheet();
        showToast('Denúncia enviada. Obrigado por avisar.');
      } else {
        showToast('Não foi possível enviar a denúncia.', true);
      }
    })
    .catch(err => console.error('Erro ao denunciar:', err));
  }

  // =======================================================
  //   FUNÇÕES UTILITÁRIAS
  // =======================================================
  function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/[&<>'"]/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;",
      '"': "&quot;", "'": "&#39;"
    }[c]));
  }

  function formatTime(isoString) {
    if (!isoString) return "";
    const d = new Date(isoString);
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  // Uma mensagem (message_id) ou várias de uma vez (message_ids — a outra pessoa abriu a conversa)
  function handleStatusUpdate(data) {
    const ids = data.message_ids || [data.message_id];
    ids.forEach((id) => {
      const el = chatWindow.querySelector(`.message-status[data-status-id="${id}"]`);
      if (el) el.className = `message-status status-${data.status}`;

      const row = document.getElementById(`msg-${id}`);
      if (row) {
        row.dataset.status = data.status;
        if (data.read_at) row.dataset.readAt = data.read_at;
      }
    });
  }

  function scrollToBottom() {
    chatWindow.scrollTop = chatWindow.scrollHeight;
  }

  // =======================================================
  //   AJUSTE DE TECLADO — Safari PWA + WkWebView (iOS app)
  // =======================================================
  const chatWrapper = document.querySelector('.chat-screen-wrapper');

  // Quanto a área visível precisa encolher para considerarmos o teclado aberto.
  const KEYBOARD_MIN_HEIGHT = 120;
  // Altura da tela SEM teclado — referência para detectar o teclado mesmo quando
  // o WKWebView redimensiona a página inteira (aí innerHeight também encolhe).
  let fullViewportHeight = Math.max(window.innerHeight, window.visualViewport ? window.visualViewport.height : 0);

  function adjustToViewport() {
    if (!chatWrapper) return;
    // visualViewport é preciso no Safari; em WkWebView pode não atualizar
    // window.innerHeight é o fallback confiável no WkWebView
    const vv     = window.visualViewport;
    const height = vv ? vv.height   : window.innerHeight;
    const top    = vv ? vv.offsetTop : 0;
    const focused = document.activeElement === messageInput;

    if (!focused) fullViewportHeight = Math.max(window.innerHeight, height);

    chatWrapper.style.height = height + 'px';
    chatWrapper.style.top    = top    + 'px';

    // Com o teclado aberto, o respiro de safe-area do rodapé (home indicator e,
    // no app iOS, a tab bar nativa: ~83px) fica atrás do teclado e virava um vão
    // vazio entre o campo e o teclado. A classe faz o CSS zerar esse respiro.
    const keyboardOpen = focused && (fullViewportHeight - height) > KEYBOARD_MIN_HEIGHT;
    chatWrapper.classList.toggle('keyboard-open', keyboardOpen);

    requestAnimationFrame(scrollToBottom);
  }

  // visualViewport.resize — funciona no Safari browser
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', adjustToViewport);
    window.visualViewport.addEventListener('scroll', adjustToViewport);
  }
  // window.resize — funciona no WkWebView onde visualViewport.resize pode não disparar
  window.addEventListener('resize', adjustToViewport);

  adjustToViewport();
  requestAnimationFrame(() => { adjustToViewport(); scrollToBottom(); });

  messageInput.addEventListener('focus', () => {
    // Dois retries para cobrir a animação do teclado iOS (~300ms)
    setTimeout(() => { adjustToViewport(); scrollToBottom(); }, 120);
    setTimeout(() => { adjustToViewport(); scrollToBottom(); }, 380);
  });

  messageInput.addEventListener('blur', () => {
    if (chatWrapper) {
      chatWrapper.style.height = '';
      chatWrapper.style.top    = '';
      chatWrapper.classList.remove('keyboard-open');
    }
    setTimeout(scrollToBottom, 100);
  });

  // =======================================================
  //   GESTOS NA ÁREA DE MENSAGENS
  //   ← esquerda : revela os horários (estilo Instagram)
  //   → direita  : responde a mensagem arrastada (estilo WhatsApp)
  //   toque      : na citação, leva até a mensagem original; fora dela,
  //                fecha o teclado (comportamento WhatsApp)
  //
  //   Tudo em fase de captura: o long-press das linhas chama preventDefault e
  //   stopPropagation no touchstart — por isso o toque na citação também é
  //   tratado aqui (o navegador não gera "click" depois daquele preventDefault).
  //
  //   O teclado só fecha num toque simples ou ao rolar na vertical — antes
  //   fechava já no touchstart, e arrastar para responder com o teclado aberto
  //   fazia ele fechar e abrir de novo.
  // =======================================================
  (function setupMessageGestures() {
    if (!slideContainer) return;

    const MAX_SLIDE       = 52;  // ← quanto a lista anda para mostrar os horários
    const MAX_REPLY_SLIDE = 76;  // → quanto a mensagem anda ao ser arrastada
    const REPLY_THRESHOLD = 56;  // → soltar a partir daqui responde
    const TAP_MAX_MS      = 450; // mais que isso é toque longo (abre o menu)

    let startX = 0, startY = 0, startTime = 0;
    let active = false, directionLocked = false, isHorizontal = false;
    let startTarget = null, swipeRow = null, replyArmed = false;
    let lastTouchAt = 0;

    function onStart(x, y, target) {
      startX = x;
      startY = y;
      startTime = Date.now();
      active = true;
      directionLocked = false;
      isHorizontal = false;
      startTarget = target;
      swipeRow = target && target.closest ? target.closest('.message-row') : null;
      replyArmed = false;
    }

    // true quando o gesto é horizontal — aí a rolagem da conversa é bloqueada
    function onMove(x, y) {
      if (!active) return false;
      const dx = x - startX;               // positivo = moveu para a direita
      const dy = Math.abs(y - startY);

      if (!directionLocked) {
        if (Math.abs(dx) < 5 && dy < 5) return false;
        directionLocked = true;
        isHorizontal = Math.abs(dx) > dy;
        if (!isHorizontal) blurInput();    // rolagem vertical: fecha o teclado
      }
      if (!isHorizontal) return false;

      if (dx < 0) {
        dragReply(0);
        slideContainer.classList.add('is-dragging');
        slideContainer.style.transform = `translateX(-${Math.min(-dx, MAX_SLIDE)}px)`;
      } else {
        slideContainer.style.transform = '';
        dragReply(dx);
      }
      return true;
    }

    function dragReply(dx) {
      if (!swipeRow) return;
      const offset = Math.min(dx, MAX_REPLY_SLIDE);
      swipeRow.classList.add('is-reply-dragging');
      swipeRow.style.transform = offset ? `translateX(${offset}px)` : '';
      // 0 → 1: faz o ícone de resposta surgir à esquerda (ver chat.scss)
      swipeRow.style.setProperty('--reply-progress', Math.min(offset / REPLY_THRESHOLD, 1).toFixed(2));

      const armed = offset >= REPLY_THRESHOLD;
      if (armed && !replyArmed && navigator.vibrate) navigator.vibrate(12);
      replyArmed = armed;
    }

    function releaseRow() {
      if (!swipeRow) return;
      swipeRow.classList.remove('is-reply-dragging');
      swipeRow.style.transform = '';
      swipeRow.style.removeProperty('--reply-progress');
    }

    function resetSlide() {
      slideContainer.classList.remove('is-dragging');
      slideContainer.style.transform = '';
    }

    function onEnd() {
      if (!active) return;
      active = false;
      resetSlide();

      if (isHorizontal) {
        const row = swipeRow;
        const shouldReply = replyArmed && row;
        releaseRow();
        if (shouldReply) startReply(row);
        return;
      }

      if (directionLocked) return; // foi rolagem vertical — teclado já fechado

      // Toque simples
      const quote = startTarget && startTarget.closest ? startTarget.closest('.msg-quote') : null;
      if (quote && Date.now() - startTime < TAP_MAX_MS) {
        jumpToMessage(quote.dataset.replyToId);
        return;
      }
      blurInput();
    }

    function onCancel() {
      if (!active) return;
      active = false;
      resetSlide();
      releaseRow();
    }

    function blurInput() {
      if (document.activeElement === messageInput) messageInput.blur();
    }

    // — Touch
    chatWindow.addEventListener('touchstart', (e) => {
      lastTouchAt = Date.now();
      if (e.touches.length > 1) { onCancel(); return; } // pinça/dois dedos: ignora
      const t = e.touches[0];
      onStart(t.clientX, t.clientY, e.target);
    }, { passive: true, capture: true });

    chatWindow.addEventListener('touchmove', (e) => {
      const t = e.touches[0];
      if (onMove(t.clientX, t.clientY)) e.preventDefault();
    }, { passive: false, capture: true });

    chatWindow.addEventListener('touchend', () => {
      lastTouchAt = Date.now();
      onEnd();
    }, { capture: true });
    chatWindow.addEventListener('touchcancel', onCancel, { capture: true });

    // — Mouse (desktop). Ignora o mouse que o navegador simula logo após um toque.
    const justTouched = () => Date.now() - lastTouchAt < 800;
    chatWindow.addEventListener('mousedown', (e) => {
      if (e.button !== 0 || justTouched()) return;
      onStart(e.clientX, e.clientY, e.target);
    });
    chatWindow.addEventListener('mousemove', (e) => { if (!justTouched()) onMove(e.clientX, e.clientY); });
    chatWindow.addEventListener('mouseup',   () => { if (!justTouched()) onEnd(); });
    chatWindow.addEventListener('mouseleave', onCancel);

    // — Teclado: Enter/Espaço na citação focada (clique sem ponteiro tem detail 0)
    chatWindow.addEventListener('click', (e) => {
      if (e.detail !== 0) return;
      const quote = e.target.closest && e.target.closest('.msg-quote');
      if (quote) jumpToMessage(quote.dataset.replyToId);
    });
  })();
});
