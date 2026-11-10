import { Controller } from "@hotwired/stimulus"

// "Responda perguntas com o Gold" (users/_prompt_gold_modal.html.erb): quem não é Gold toca
// em "Responder" numa pergunta do perfil (botão com data-prompt-gold-open).
//
// O aviso vai para o <body> ao conectar: dentro da folha do perfil no mapa (que usa
// transform) um position: fixed fica preso à folha — abria no topo do conteúdo, fora da
// tela de quem tinha rolado até a pergunta, e o toque parecia não fazer nada.
// X, "Agora não", tocar fora ou Esc fecham.
export default class extends Controller {
  static targets = ["question", "answer"]

  connect() {
    if (this.element.parentElement !== document.body) {
      document.body.appendChild(this.element) // reconecta já no body
      return
    }
    // Só o aviso do perfil aberto agora (o mapa troca de perfil sem trocar de página)
    document.querySelectorAll("body > .pg-overlay").forEach((el) => { if (el !== this.element) el.remove() })
  }

  disconnect() {
    document.body.classList.remove("pg-lock")
  }

  open(event) {
    const { question, answer } = event.detail || {}
    if (this.hasQuestionTarget) this.questionTarget.textContent = question || ""
    if (this.hasAnswerTarget) this.answerTarget.textContent = answer || ""

    this.element.hidden = false
    requestAnimationFrame(() => this.element.classList.add("is-open"))
    document.body.classList.add("pg-lock")
    this.element.querySelector(".pg-cta")?.focus({ preventScroll: true })
  }

  close() {
    if (this.element.hidden) return
    this.element.classList.remove("is-open")
    this.element.hidden = true
    document.body.classList.remove("pg-lock")
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }
}

// "Responder" de quem não é Gold: abre o aviso; se ele não estiver na página, vai aos planos
if (!window.__gmPromptGoldWired) {
  window.__gmPromptGoldWired = true
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-prompt-gold-open]")
    if (!button) return
    event.preventDefault()

    if (!document.querySelector(".pg-overlay")) {
      if (window.Turbo) window.Turbo.visit("/plans")
      else window.location.href = "/plans"
      return
    }
    window.dispatchEvent(new CustomEvent("prompt-gold:open", {
      detail: { question: button.dataset.question, answer: button.dataset.answer }
    }))
  })
}
