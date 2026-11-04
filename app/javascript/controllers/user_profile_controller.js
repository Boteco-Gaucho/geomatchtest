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
