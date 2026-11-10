import { Controller } from "@hotwired/stimulus"

// Aviso no topo da tela (shared/_top_toast.html.erb): desce, some sozinho depois de
// `duration` ms (com a barra de tempo, quando tem) e tocar fecha antes.
// Vem do servidor (conta descongelada) ou de um <template> copiado pelo JS
// (avisos da idade — privacy_toggle_controller).
const LEAVE_MS = 260

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    // Um aviso por vez: os do flash comum (shared/_flash) ainda na tela saem
    document.querySelectorAll("#toast-container .toast").forEach((el) => el.remove())
    this.element.style.setProperty("--tt-duration", `${this.durationValue}ms`)
    requestAnimationFrame(() => this.element.classList.add("is-in"))
    this._timer = setTimeout(() => this.dismiss(), this.durationValue)
  }

  dismiss(event) {
    // Toque no botão de ação (ex.: Desfazer): deixa o formulário enviar
    if (event?.target?.closest?.("[data-tt-keep]")) return
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
