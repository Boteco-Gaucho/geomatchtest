import { Controller } from "@hotwired/stimulus"
import { showToast } from "../show_toast"

// "Sair da sua conta?" — folha inferior de Meu Perfil.
// Fecha com "Continuar no GeoMatch", toque fora, Esc ou arrastando para baixo.
// "Sair" faz DELETE da sessão (Users::SessionsController#destroy responde JSON) e
// recarrega: sem login, a página manda para a entrada.
const CLOSE_MS = 280
const DRAG_CLOSE_PX = 90

export default class extends Controller {
  static targets = ["backdrop", "sheet", "stay", "leave"]
  static values = { url: String }

  open() {
    clearTimeout(this._timer)
    this._opener = document.activeElement
    this.backdropTarget.hidden = false
    this.sheetTarget.style.transform = ""
    requestAnimationFrame(() => this.backdropTarget.classList.add("is-open"))
    document.documentElement.classList.add("ls-lock")
    this.stayTarget.focus({ preventScroll: true })
  }

  close() {
    if (this.backdropTarget.hidden || this._leaving) return

    this.backdropTarget.classList.remove("is-open")
    this.sheetTarget.style.transform = ""
    document.documentElement.classList.remove("ls-lock")
    this._timer = setTimeout(() => { this.backdropTarget.hidden = true }, CLOSE_MS)
    this._opener?.focus?.({ preventScroll: true })
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  async logout() {
    if (this._leaving) return
    this._leaving = true
    this.leaveTarget.disabled = true
    this.leaveTarget.textContent = "Saindo..."

    try {
      const response = await fetch(this.urlValue, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      window.location.reload()
    } catch (error) {
      console.error("[GeoMatch] Erro ao sair:", error)
      this._leaving = false
      this.leaveTarget.disabled = false
      this.leaveTarget.textContent = "Sair"
      showToast("Não deu para sair agora. Verifique a conexão e tente de novo.", true)
    }
  }

  // Arrastar a folha para baixo (no celular)
  dragStart(event) {
    this._dragY = event.touches[0].clientY
    this._dragDelta = 0
    this.sheetTarget.classList.add("is-dragging")
  }

  dragMove(event) {
    if (this._dragY == null) return
    this._dragDelta = Math.max(0, event.touches[0].clientY - this._dragY)
    this.sheetTarget.style.transform = `translateY(${this._dragDelta}px)`
  }

  dragEnd() {
    if (this._dragY == null) return
    this.sheetTarget.classList.remove("is-dragging")
    const dragged = this._dragDelta
    this._dragY = null
    if (dragged > DRAG_CLOSE_PX) {
      this.close()
    } else {
      this.sheetTarget.style.transform = ""
    }
  }

  // Antes do Turbo guardar a página no cache: folha fechada
  reset() {
    clearTimeout(this._timer)
    this.backdropTarget.classList.remove("is-open")
    this.backdropTarget.hidden = true
    document.documentElement.classList.remove("ls-lock")
  }

  disconnect() {
    clearTimeout(this._timer)
    document.documentElement.classList.remove("ls-lock")
  }
}
