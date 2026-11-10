import { Controller } from "@hotwired/stimulus"

// "Responda perguntas com o Gold" (users/_prompt_gold_modal.html.erb): quem não é Gold toca
// em Responder numa pergunta do perfil. O cartão do meio mostra a pergunta tocada.
// X, "Agora não", tocar fora ou Esc fecham.
export default class extends Controller {
  static targets = ["overlay", "question", "answer"]

  open({ params }) {
    if (!this.hasOverlayTarget) return
    if (this.hasQuestionTarget) this.questionTarget.textContent = params.question || ""
    if (this.hasAnswerTarget) this.answerTarget.textContent = params.answer || ""

    this.overlayTarget.hidden = false
    requestAnimationFrame(() => this.overlayTarget.classList.add("is-open"))
    document.body.classList.add("pg-lock")
  }

  close() {
    if (!this.hasOverlayTarget || this.overlayTarget.hidden) return
    this.overlayTarget.classList.remove("is-open")
    this.overlayTarget.hidden = true
    document.body.classList.remove("pg-lock")
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }
}
