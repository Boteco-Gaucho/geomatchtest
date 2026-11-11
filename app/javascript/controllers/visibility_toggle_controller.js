import { Controller } from "@hotwired/stimulus"

// Botão "modo invisível" (navegação 100% oculta) — usado na galeria de perfis.
//
// Mesmo contrato do FAB de visibilidade do mapa 3D:
//   POST /users/toggle_visibility → { invisible: bool }
//   403 + { upgrade_required: true } → abre o modal de planos (recurso Gold)
export default class extends Controller {
  static targets = ["eyeOpen", "eyeClosed"]
  static values  = { invisible: Boolean }

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
        if (data.upgrade_required) await this.showUpgradeModal()
        return
      }

      if (!response.ok) throw new Error("Erro ao salvar no servidor")
      const data = await response.json()
      this.invisibleValue = data.invisible
      this.render()
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
  }

  // Mesmo fluxo de upgrade do mapa (map_3d.js): injeta o modal de planos
  // no container e liga os fechamentos.
  async showUpgradeModal() {
    const container = document.getElementById("upgrade-modal-container")
    if (!container) return

    const res = await fetch("/plans/modal?type=invisible")
    container.innerHTML = await res.text()

    const backdrop = container.querySelector(".upgrade-modal-backdrop")
    const close = () => {
      if (backdrop) {
        backdrop.style.opacity = "0"
        setTimeout(() => { container.innerHTML = "" }, 300)
      }
    }
    container.querySelectorAll(".close-modal-btn").forEach(btn => {
      btn.onclick = (e) => { e.preventDefault(); close() }
    })
    if (backdrop) {
      backdrop.onclick = (e) => { if (e.target === backdrop) close() }
    }
  }
}
