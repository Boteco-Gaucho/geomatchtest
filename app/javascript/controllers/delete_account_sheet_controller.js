import BottomSheetController from "./bottom_sheet_controller"

// "Encerrar sua conta?" — folha inferior de Meu Perfil (base: bottom_sheet_controller.js).
// O botão "Encerrar conta" só libera depois de digitar a palavra (sem diferenciar
// maiúsculas). Ele envia o DELETE /users do Devise (registrations#destroy).
export default class extends BottomSheetController {
  static targets = ["input", "submit"] // + backdrop, sheet, stay (herdados)
  static values = { word: { type: String, default: "ENCERRAR" } }

  opened() {
    this.inputTarget.value = ""
    this.check()
  }

  check() {
    this.submitTarget.disabled = this.inputTarget.value.trim().toUpperCase() !== this.wordValue
  }

  submit(event) {
    if (this.submitTarget.disabled || this.busy) {
      event.preventDefault()
      return
    }
    this.busy = true // a folha não fecha mais enquanto a conta é apagada
    // Desabilita no próximo ciclo: desabilitar já agora cancelaria o envio do formulário
    setTimeout(() => {
      this.submitTarget.disabled = true
      this.submitTarget.textContent = "Encerrando..."
    })
  }

  reset() {
    super.reset()
    this.busy = false
    this.inputTarget.value = ""
    this.check()
  }
}
