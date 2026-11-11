import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "trigger"]

  connect() {
    this._onOutsideClick = this._handleOutsideClick.bind(this)
    this._onKeydown      = this._handleKeydown.bind(this)
  }

  disconnect() {
    this._removeListeners()
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click",   this._onOutsideClick)
    document.addEventListener("keydown", this._onKeydown)
  }

  close() {
    this.menuTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this._removeListeners()
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  _handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  _removeListeners() {
    document.removeEventListener("click",   this._onOutsideClick)
    document.removeEventListener("keydown", this._onKeydown)
  }
}
