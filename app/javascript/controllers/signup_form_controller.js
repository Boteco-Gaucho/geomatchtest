import { Controller } from "@hotwired/stimulus"

// Tela Criar conta (devise/registrations/new): olho das senhas, a regra
// "Mínimo de N caracteres" fica verde quando a senha chega lá, e a máscara do
// celular "(71) 99999-9999" (o +55 fica fixo ao lado; o servidor grava +55…).
export default class extends Controller {
  static targets = ["password", "rule"]
  static values = { min: { type: Number, default: 6 } }

  connect() {
    this.checkLength()
  }

  toggle(event) {
    const button = event.currentTarget
    const input = button.parentElement.querySelector("input")
    const show = input.type === "password"
    input.type = show ? "text" : "password"
    button.setAttribute("aria-pressed", String(show))
    button.setAttribute("aria-label", show ? "Esconder senha" : "Mostrar senha")
    button.classList.toggle("is-showing", show)
  }

  checkLength() {
    if (!this.hasPasswordTarget || !this.hasRuleTarget) return
    this.ruleTarget.classList.toggle("is-ok", this.passwordTarget.value.length >= this.minValue)
  }

  maskPhone(event) {
    const input = event.currentTarget
    const digits = input.value.replace(/\D/g, "").slice(0, 11)
    let text = digits
    if (digits.length > 2) text = `(${digits.slice(0, 2)}) ${digits.slice(2)}`
    if (digits.length > 7) {
      const split = digits.length === 11 ? 7 : 6
      text = `(${digits.slice(0, 2)}) ${digits.slice(2, split)}-${digits.slice(split)}`
    }
    input.value = text
  }
}
