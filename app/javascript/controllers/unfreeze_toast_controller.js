import { Controller } from "@hotwired/stimulus"

// "Que bom que você ficou!" (shared/_unfreeze_toast.html.erb): desce, mostra a barra
// de tempo e some sozinho depois de `duration` ms. Tocar fecha antes.
const LEAVE_MS = 260

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    this.element.style.setProperty("--uf-duration", `${this.durationValue}ms`)
    requestAnimationFrame(() => this.element.classList.add("is-in"))
    this._timer = setTimeout(() => this.dismiss(), this.durationValue)
  }

  dismiss() {
    clearTimeout(this._timer)
    if (this.element.classList.contains("is-out")) return
    this.element.classList.remove("is-in")
    this.element.classList.add("is-out")
    this._timer = setTimeout(() => this.remove(), LEAVE_MS)
  }

  // Também antes do Turbo guardar a página: voltar não mostra o aviso de novo
  remove() {
    clearTimeout(this._timer)
    this.element.remove()
  }

  disconnect() {
    clearTimeout(this._timer)
  }
}
