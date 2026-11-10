import { Controller } from "@hotwired/stimulus"

// Perfil de outra pessoa (/users/:id): voltar e o "X" (passar a vez).
// O X registra o "não" sem sair da tela por redirect (o users#reject responde
// 200 com source=profile) e então volta para onde a pessoa estava — galeria,
// mapa, curtidas, chat… Sem histórico (link aberto direto), vai para o fallback.
export default class extends Controller {
  static values = { fallback: String }

  back(event) {
    if (window.history.length > 1) {
      event.preventDefault()
      window.history.back()
    }
  }

  async pass(event) {
    event.preventDefault()
    const form = event.target
    const button = form.querySelector("button")
    if (button) button.disabled = true

    try {
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: { Accept: "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.leave()
    } catch (error) {
      console.error("[user-profile] não deu para passar:", error)
      if (button) button.disabled = false
    }
  }

  // Coração vermelho (ainda não curtiu): fica escuro já no toque; o Turbo envia a curtida e o
  // servidor confirma trocando o bloco (ou abre o "É um match!"). Falhou: volta a vermelho.
  like(event) {
    const form = event.target
    const button = form.querySelector("button")
    if (!button) return
    if (button.classList.contains("is-liked")) {
      event.preventDefault()
      this.alreadyLiked({ currentTarget: button, preventDefault() {} })
      return
    }
    button.classList.add("is-liked")
    button.setAttribute("aria-pressed", "true")
    form.addEventListener("turbo:submit-end", (e) => {
      if (e.detail.success) return
      button.classList.remove("is-liked")
      button.setAttribute("aria-pressed", "false")
    }, { once: true })
  }

  // Coração escuro (já curtiu): só avisa — nenhuma curtida nova é enviada
  alreadyLiked(event) {
    if (event) event.preventDefault()
    const message = event?.currentTarget?.dataset?.notice || "Você já curtiu este usuário."
    const container = document.getElementById("toast-container")
    if (!container) return
    container.querySelector("[data-already-liked]")?.remove()

    const toast = document.createElement("div")
    toast.className = "toast toast--notice"
    toast.dataset.controller = "toast"
    toast.dataset.alreadyLiked = ""
    toast.setAttribute("role", "alert")
    toast.setAttribute("aria-live", "polite")
    toast.innerHTML = '<span class="toast__message"></span>' +
                      '<button class="toast__close" data-action="toast#close" aria-label="Fechar">✕</button>'
    toast.querySelector(".toast__message").textContent = message
    container.prepend(toast)
  }

  leave() {
    if (window.history.length > 1) {
      window.history.back()
    } else if (window.Turbo) {
      window.Turbo.visit(this.fallbackValue, { action: "replace" })
    } else {
      window.location.replace(this.fallbackValue)
    }
  }
}
