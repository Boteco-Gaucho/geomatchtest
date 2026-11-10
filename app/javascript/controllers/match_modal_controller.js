import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet", "eyebrow", "leftAvatar", "rightAvatar", "messageBtn", "autoHint"]
  static values  = {
    messagePath: String,
    dismissPath: String,
    autoOpen:    { type: Boolean, default: true },
    // > 0: depois desse tempo (ms) abre a conversa sozinho — retribuir em Curtidas/perfil
    autoForward: { type: Number, default: 0 }
  }

  connect() {
    this.boundShow = this.show.bind(this)
    document.addEventListener("match:show", this.boundShow)

    this.boundKey = (e) => { if (e.key === "Escape") this.dismiss() }
    document.addEventListener("keydown", this.boundKey)

    if (this.autoOpenValue) this.open()
  }

  disconnect() {
    clearTimeout(this.forwardTimer)
    document.removeEventListener("match:show", this.boundShow)
    document.removeEventListener("keydown", this.boundKey)
  }

  show(event) {
    const d = (event && event.detail) || {}
    if (d.eyebrow      && this.hasEyebrowTarget)     this.eyebrowTarget.textContent = d.eyebrow
    if (d.leftName     && this.hasLeftAvatarTarget)  this.setAvatar(this.leftAvatarTarget,  d.leftAvatar,  d.leftName)
    if (d.rightName    && this.hasRightAvatarTarget) this.setAvatar(this.rightAvatarTarget, d.rightAvatar, d.rightName)
    if (d.messagePath && this.hasMessageBtnTarget) {
      this.messagePathValue = d.messagePath
      this.messageBtnTarget.href = d.messagePath
    }
    if (d.dismissPath) this.dismissPathValue = d.dismissPath

    this.open()
  }

  open() {
    this.element.removeAttribute("hidden")
    void this.element.offsetWidth
    this.element.classList.remove("is-closing")
    document.body.style.overflow = "hidden"

    clearTimeout(this.forwardTimer)
    if (this.autoForwardValue > 0) {
      this.forwardTimer = setTimeout(() => this.goToChat(), this.autoForwardValue)
    }
  }

  goToChat() {
    const path = this.messagePathValue
    if (!path || path === "#") return
    document.body.style.overflow = ""
    this.element.remove()
    if (window.Turbo) Turbo.visit(path)
    else window.location.href = path
  }

  dismiss(event) {
    if (event) event.preventDefault()
    clearTimeout(this.forwardTimer)
    this.element.classList.add("is-closing")
    document.body.style.overflow = ""
    setTimeout(() => {
      this.element.remove()
      const path = this.dismissPathValue
      if (path && path !== "#") {
        if (window.Turbo) {
          Turbo.visit(path, { action: "replace" })
        } else {
          window.location.href = path
        }
      }
    }, 300)
  }

  sendMessage(_event) {
    clearTimeout(this.forwardTimer)
    document.body.style.overflow = ""
    this.element.remove()
  }

  setAvatar(el, url, name) {
    if (url) {
      el.innerHTML = `<img src="${url}" alt="${this.escape(name)}">`
    } else {
      const initials = name.trim().split(/\s+/).slice(0, 2).map(s => s[0].toUpperCase()).join("")
      el.innerHTML = `<div class="gm-match__initials">${this.escape(initials)}</div>`
    }
  }

  escape(s) {
    return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]))
  }
}
