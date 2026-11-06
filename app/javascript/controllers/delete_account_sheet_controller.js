import BottomSheetController from "./bottom_sheet_controller"

// "Encerrar sua conta?" — folha inferior de Meu Perfil (base: bottom_sheet_controller.js).
// Passo 1: "Encerrar conta" só libera depois de digitar a palavra (sem diferenciar maiúsculas).
// Passo 2 (freezeStep): "Que tal congelar sua conta?" — "Vou congelar" envia POST /conta/congelar;
// "Vou encerrar mesmo assim" (leave, form="ds-form") envia o DELETE /users do Devise.
// Sem o passo 2 na página (coluna frozen_at ausente), o passo 1 apaga direto.
export default class extends BottomSheetController {
  static targets = ["input", "submit", "confirmStep", "freezeStep", "freezeButton", "leave"] // + backdrop, sheet, stay (herdados)
  static values = { word: { type: String, default: "ENCERRAR" } }

  opened() {
    this.showConfirm()
    this.inputTarget.value = ""
    this.check()
  }

  check() {
    this.submitTarget.disabled = this.inputTarget.value.trim().toUpperCase() !== this.wordValue
  }

  // Envio do formulário de exclusão: pelo passo 1 mostra o congelar; pelo "Vou encerrar
  // mesmo assim" (ou sem passo 2) apaga de verdade
  submit(event) {
    if (this.busy || this.submitTarget.disabled) {
      event.preventDefault()
      return
    }

    const deleting = !this.hasFreezeStepTarget || event.submitter === this.leaveTarget
    if (!deleting) {
      event.preventDefault()
      this.showFreeze()
      return
    }

    const button = this.hasLeaveTarget && event.submitter === this.leaveTarget ? this.leaveTarget : this.submitTarget
    this.lock(button, "Encerrando...")
  }

  freeze() {
    if (this.busy) return
    this.lock(this.freezeButtonTarget, "Congelando...")
  }

  showFreeze() {
    this.confirmStepTarget.hidden = true
    this.freezeStepTarget.hidden = false
    this.sheetTarget.setAttribute("aria-labelledby", "fz-title")
    this.sheetTarget.setAttribute("aria-describedby", "fz-text")
    this.sheetTarget.scrollTop = 0
    this.freezeButtonTarget.focus({ preventScroll: true })
  }

  showConfirm() {
    if (!this.hasFreezeStepTarget) return
    this.freezeStepTarget.hidden = true
    this.confirmStepTarget.hidden = false
    this.sheetTarget.setAttribute("aria-labelledby", "ds-title")
    this.sheetTarget.setAttribute("aria-describedby", "ds-text")
  }

  // A folha não fecha mais enquanto a conta é apagada/congelada. Desabilita no próximo
  // ciclo: desabilitar já agora cancelaria o envio do formulário.
  lock(button, label) {
    this.busy = true
    setTimeout(() => {
      button.disabled = true
      const text = button.querySelector("span") || button
      text.textContent = label
    })
  }

  reset() {
    super.reset()
    this.busy = false
    this.showConfirm()
    this.inputTarget.value = ""
    this.check()
  }
}
