import { Controller } from "@hotwired/stimulus"

// Gold respondendo uma pergunta do perfil (users/_profile_prompt.html.erb): "Responder" abre
// o campo ali mesmo; o envio vai pelo Turbo e o servidor troca o cartão inteiro pelo estado
// "Respondida" e mostra o aviso "Resposta enviada". Falhou: o texto continua no campo.
export default class extends Controller {
  static targets = ["open", "form", "input", "send"]

  open() {
    this.openTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.focus()
  }

  cancel() {
    this.formTarget.hidden = true
    this.openTarget.hidden = false
  }

  // Enter envia; Shift+Enter quebra a linha
  submitOnEnter(event) {
    if (event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (this.inputTarget.value.trim()) this.formTarget.requestSubmit()
  }

  sending() {
    this.sendTarget.disabled = true
    this.sendTarget.textContent = "Enviando…"
  }

  sent(event) {
    if (event.detail.success) return
    this.sendTarget.disabled = false
    this.sendTarget.textContent = "Enviar"
  }
}
