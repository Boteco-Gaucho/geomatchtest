import { Controller } from "@hotwired/stimulus"

// "Desfazer match com …?" (matches/_unmatch_confirm.html.erb). Abre pelo item do menu
// (evento unmatch:open). "Não, manter", tocar fora ou Esc fecham e voltam para a conversa.
// "Sim" envia o DELETE e o servidor leva para Mensagens com o aviso "Match desfeito".
export default class extends Controller {
  static targets = ["confirm"]

  open() {
    this.element.hidden = false
    requestAnimationFrame(() => this.element.classList.add("is-open"))
    document.body.classList.add("um-lock")
    this.element.querySelector(".um-btn--ghost")?.focus({ preventScroll: true })
  }

  close() {
    if (this.element.hidden) return
    this.element.classList.remove("is-open")
    document.body.classList.remove("um-lock")
    this.element.hidden = true
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }

  // Um toque só: evita dois envios enquanto o servidor responde
  submitting() {
    if (this.hasConfirmTarget) this.confirmTarget.setAttribute("aria-busy", "true")
    setTimeout(() => { if (this.hasConfirmTarget) this.confirmTarget.disabled = true }, 0)
  }
}
