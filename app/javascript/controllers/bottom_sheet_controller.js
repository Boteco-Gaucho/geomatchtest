import { Controller } from "@hotwired/stimulus"

// Base das folhas inferiores de Meu Perfil ("Sair" e "Encerrar conta"): abre, fecha
// (botão, toque fora, Esc, arrastar para baixo) e se fecha antes do cache do Turbo.
// Cada folha estende esta classe; targets: backdrop, sheet e stay (foco ao abrir).
const CLOSE_MS = 280
const DRAG_CLOSE_PX = 90

export default class extends Controller {
  static targets = ["backdrop", "sheet", "stay"]

  open() {
    clearTimeout(this._timer)
    this._opener = document.activeElement
    this.backdropTarget.hidden = false
    this.sheetTarget.style.transform = ""
    requestAnimationFrame(() => this.backdropTarget.classList.add("is-open"))
    document.documentElement.classList.add("ls-lock")
    if (this.hasStayTarget) this.stayTarget.focus({ preventScroll: true })
    this.opened()
  }

  close() {
    if (this.backdropTarget.hidden || this.busy) return

    this.backdropTarget.classList.remove("is-open")
    this.sheetTarget.style.transform = ""
    document.documentElement.classList.remove("ls-lock")
    this._timer = setTimeout(() => { this.backdropTarget.hidden = true }, CLOSE_MS)
    this._opener?.focus?.({ preventScroll: true })
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  // Ganchos das subclasses
  opened() {}

  // Arrastar a folha para baixo (no celular) — não vale começando num campo de texto
  dragStart(event) {
    if (event.target.closest("input, textarea")) return
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
