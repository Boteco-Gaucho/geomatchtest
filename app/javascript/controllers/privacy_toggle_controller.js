import { Controller } from "@hotwired/stimulus"
import { openUpgradeModal } from "../upgrade_modal"
import { showToast } from "../show_toast"

// Interruptor da tela Privacidade e localização (e "Não mostrar minha idade" de Meu Perfil).
//   POST url → { [key]: bool }   (ligado = valor true)
//   403 { upgrade_required } → modal do Gold · 503 → recurso ainda indisponível
// Com os <template> onToast/offToast (users/_age_toasts.html.erb), mostra o aviso do
// novo estado no topo da tela (shared/_top_toast, top_toast_controller.js).
export default class extends Controller {
  static targets = ["switch", "onToast", "offToast"]
  static values = {
    url: String,
    key: String,
    checked: Boolean,
    upgrade: { type: String, default: "gold" } // tipo do modal (/plans/modal?type=)
  }

  async toggle() {
    if (this._busy) return
    this._busy = true
    this.switchTarget.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      if (response.status === 403) {
        const data = await response.json().catch(() => ({}))
        if (data.upgrade_required) await openUpgradeModal(this.upgradeValue)
        return
      }
      if (response.status === 503) {
        showToast("Esse recurso ainda não está disponível. Tente mais tarde.", true)
        return
      }
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()
      this.checkedValue = data[this.keyValue] === true
      this.announce()
    } catch (error) {
      console.error("[GeoMatch] Interruptor de privacidade:", error)
      showToast("Não deu para mudar agora. Verifique a conexão e tente de novo.", true)
    } finally {
      this._busy = false
      this.switchTarget.removeAttribute("aria-busy")
    }
  }

  // Um aviso por vez: o novo substitui o que ainda estiver na tela
  announce() {
    const template = this.checkedValue
      ? (this.hasOnToastTarget && this.onToastTarget)
      : (this.hasOffToastTarget && this.offToastTarget)
    const toast = template?.content.firstElementChild
    if (!toast) return

    document.querySelectorAll(".tt-toast").forEach((el) => el.remove())
    document.body.appendChild(toast.cloneNode(true))
  }

  checkedValueChanged() {
    this.switchTarget.setAttribute("aria-checked", String(this.checkedValue))
    this.element.classList.toggle("is-on", this.checkedValue)
  }
}
