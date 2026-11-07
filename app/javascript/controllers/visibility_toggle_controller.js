import { Controller } from "@hotwired/stimulus"
import { openUpgradeModal } from "../upgrade_modal"
import { MAP_TOASTS, showMapToast } from "../map_toast"

// Botão "modo invisível" (navegação 100% oculta) — usado na galeria de perfis.
//
// Mesmo contrato do FAB de visibilidade do mapa 3D:
//   POST /users/toggle_visibility → { invisible: bool }
//   403 + { upgrade_required: true } → abre o modal de planos (recurso Gold)
// toast (Meu Perfil): mostra o mesmo aviso do mapa — "Modo oculto ativado/desativado"
export default class extends Controller {
  // switch (opcional): interruptor "Modo oculto" de Meu Perfil (aria-checked)
  static targets = ["eyeOpen", "eyeClosed", "switch"]
  static values  = { invisible: Boolean, toast: Boolean }

  connect() {
    this.render()
  }

  async toggle() {
    try {
      const token = document.querySelector('meta[name="csrf-token"]').content
      const response = await fetch("/users/toggle_visibility", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token }
      })

      if (response.status === 403) {
        const data = await response.json()
        if (data.upgrade_required) await openUpgradeModal("invisible")
        return
      }

      if (!response.ok) throw new Error("Erro ao salvar no servidor")
      const data = await response.json()
      this.invisibleValue = data.invisible
      this.render()
      if (this.toastValue) showMapToast(data.invisible ? MAP_TOASTS.hiddenOn : MAP_TOASTS.hiddenOff)
    } catch (e) {
      console.error("[GeoMatch] Erro ao alternar visibilidade:", e)
    }
  }

  render() {
    const invisible = this.invisibleValue
    this.element.classList.toggle("is-invisible", invisible)
    this.element.title = invisible
      ? "Você está invisível — toque para voltar a aparecer"
      : "Modo invisível — navegue 100% oculto"
    if (this.hasEyeOpenTarget)   this.eyeOpenTarget.style.display   = invisible ? "none" : ""
    if (this.hasEyeClosedTarget) this.eyeClosedTarget.style.display = invisible ? "" : "none"
    if (this.hasSwitchTarget)    this.switchTarget.setAttribute("aria-checked", String(invisible))
  }
}
