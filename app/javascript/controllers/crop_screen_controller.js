// app/javascript/controllers/crop_screen_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrap", "photo", "box", "form", "field"]
  static values = {
    aspectW:    { type: Number, default: 3 },
    aspectH:    { type: Number, default: 4 },
    cancelPath: String,
    minScale:   { type: Number, default: 1 },
    maxScale:   { type: Number, default: 5 }
  }

  connect() {
    this.state = {
      x: 0, y: 0,
      scale: 1,
      rotation: 0,
      flipped: false,
      dragging: false,
      dragStart: null,
      pinching: false,
      pinchStart: null,
      fitScale: 1,
      naturalW: 0,
      naturalH: 0,
      boxW: 0, boxH: 0
    }

    this._bound = {
      down:   this.onPointerDown.bind(this),
      move:   this.onPointerMove.bind(this),
      up:     this.onPointerUp.bind(this),
      wheel:  this.onWheel.bind(this),
      resize: this.onResize.bind(this),
      loaded: this.onImageLoaded.bind(this)
    }

    this.pointers = new Map()

    this.wrapTarget.addEventListener("pointerdown", this._bound.down)
    this.wrapTarget.addEventListener("pointermove", this._bound.move)
    this.wrapTarget.addEventListener("pointerup",   this._bound.up)
    this.wrapTarget.addEventListener("pointercancel", this._bound.up)
    this.wrapTarget.addEventListener("pointerleave", this._bound.up)
    this.wrapTarget.addEventListener("wheel", this._bound.wheel, { passive: false })

    window.addEventListener("resize", this._bound.resize)

    if (this.photoTarget.complete && this.photoTarget.naturalWidth) {
      this.onImageLoaded()
    } else {
      this.photoTarget.addEventListener("load", this._bound.loaded, { once: true })
    }
  }

  disconnect() {
    this.wrapTarget.removeEventListener("pointerdown", this._bound.down)
    this.wrapTarget.removeEventListener("pointermove", this._bound.move)
    this.wrapTarget.removeEventListener("pointerup",   this._bound.up)
    this.wrapTarget.removeEventListener("pointercancel", this._bound.up)
    this.wrapTarget.removeEventListener("pointerleave", this._bound.up)
    this.wrapTarget.removeEventListener("wheel", this._bound.wheel)
    window.removeEventListener("resize", this._bound.resize)
  }

  onImageLoaded() {
    const img = this.photoTarget
    this.state.naturalW = img.naturalWidth
    this.state.naturalH = img.naturalHeight
    this.fitImage()
    this.apply()
  }

  onResize() {
    this.fitImage()
    this.apply()
  }

  fitImage() {
    const boxRect = this.boxTarget.getBoundingClientRect()

    this.state.boxW = boxRect.width
    this.state.boxH = boxRect.height

    const nw = this.state.naturalW
    const nh = this.state.naturalH
    if (!nw || !nh) return

    this.photoTarget.style.width  = nw + "px"
    this.photoTarget.style.height = nh + "px"

    const fitScale = Math.max(
      this.state.boxW / nw,
      this.state.boxH / nh
    )
    this.state.fitScale = fitScale
    this.minScaleValue  = fitScale

    this.state.scale = Math.max(this.state.scale, fitScale)
    this.clamp()
  }

  apply() {
    const { x, y, scale, rotation, flipped } = this.state
    const sx = flipped ? -scale : scale
    this.photoTarget.style.transform =
      `translate(-50%, -50%) ` +
      `translate(${x}px, ${y}px) ` +
      `rotate(${rotation}deg) ` +
      `scale(${sx}, ${scale})`
  }

  clamp() {
    const { scale } = this.state
    const photoW = this.state.naturalW * scale
    const photoH = this.state.naturalH * scale

    const maxX = Math.max(0, (photoW - this.state.boxW) / 2)
    const maxY = Math.max(0, (photoH - this.state.boxH) / 2)

    this.state.x = Math.min(maxX,  Math.max(-maxX, this.state.x))
    this.state.y = Math.min(maxY,  Math.max(-maxY, this.state.y))
  }

  onPointerDown(e) {
    this.wrapTarget.setPointerCapture(e.pointerId)
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })

    if (this.pointers.size === 1) {
      this.state.dragging = true
      this.state.dragStart = {
        x: e.clientX, y: e.clientY,
        origX: this.state.x, origY: this.state.y
      }
      this.wrapTarget.setAttribute("data-dragging", "true")
    } else if (this.pointers.size === 2) {
      this.state.pinching = true
      this.state.dragging = false
      const [p1, p2] = [...this.pointers.values()]
      this.state.pinchStart = {
        dist:      Math.hypot(p2.x - p1.x, p2.y - p1.y),
        origScale: this.state.scale
      }
    }
  }

  onPointerMove(e) {
    if (!this.pointers.has(e.pointerId)) return
    this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY })

    if (this.state.pinching && this.pointers.size >= 2) {
      const [p1, p2] = [...this.pointers.values()]
      const dist = Math.hypot(p2.x - p1.x, p2.y - p1.y)
      const ratio = dist / this.state.pinchStart.dist
      const newScale = this._clampScale(this.state.pinchStart.origScale * ratio)
      this.state.scale = newScale
      this.clamp()
      this.apply()
    } else if (this.state.dragging) {
      const dx = e.clientX - this.state.dragStart.x
      const dy = e.clientY - this.state.dragStart.y
      this.state.x = this.state.dragStart.origX + dx
      this.state.y = this.state.dragStart.origY + dy
      this.clamp()
      this.apply()
    }
  }

  onPointerUp(e) {
    this.pointers.delete(e.pointerId)
    try { this.wrapTarget.releasePointerCapture(e.pointerId) } catch (_) {}

    if (this.pointers.size < 2) this.state.pinching = false
    if (this.pointers.size === 0) {
      this.state.dragging = false
      this.wrapTarget.removeAttribute("data-dragging")
    }
  }

  onWheel(e) {
    e.preventDefault()
    const delta = -e.deltaY * 0.0015
    const newScale = this._clampScale(this.state.scale * (1 + delta))
    this.state.scale = newScale
    this.clamp()
    this.apply()
  }

  zoomIn()  { this._zoomBy(1.15) }
  zoomOut() { this._zoomBy(1 / 1.15) }

  _zoomBy(factor) {
    this.state.scale = this._clampScale(this.state.scale * factor)
    this.clamp()
    this.apply()
  }

  rotate() {
    this.state.rotation = (this.state.rotation + 90) % 360
    this.fitImage()
    this.apply()
  }

  flip() {
    this.state.flipped = !this.state.flipped
    this.apply()
  }

  _clampScale(s) {
    return Math.min(this.maxScaleValue, Math.max(this.state.fitScale, s))
  }

  confirm(event) {
    if (event) event.preventDefault()

    const { scale, x, y, naturalW, naturalH, boxW, boxH, rotation, flipped } = this.state

    // Crop rectangle in original image coordinates
    const boxLeft   = -boxW / 2
    const boxTop    = -boxH / 2
    const photoLeft = x - (naturalW * scale) / 2
    const photoTop  = y - (naturalH * scale) / 2
    const cropX = Math.max(0, Math.round((boxLeft - photoLeft) / scale))
    const cropY = Math.max(0, Math.round((boxTop  - photoTop)  / scale))
    const cropW = Math.min(Math.round(boxW / scale), naturalW - cropX)
    const cropH = Math.min(Math.round(boxH / scale), naturalH - cropY)

    // Off-screen canvas — swap dimensions when rotated 90°/270°
    const canvas = document.createElement('canvas')
    const swapped = rotation % 180 !== 0
    canvas.width  = swapped ? cropH : cropW
    canvas.height = swapped ? cropW : cropH

    const ctx = canvas.getContext('2d')
    ctx.save()
    ctx.translate(canvas.width / 2, canvas.height / 2)
    ctx.rotate(rotation * Math.PI / 180)
    if (flipped) ctx.scale(-1, 1)
    ctx.drawImage(
      this.photoTarget,
      cropX, cropY, cropW, cropH,
      -cropW / 2, -cropH / 2, cropW, cropH
    )
    ctx.restore()

    canvas.toBlob((blob) => {
      const fd = new FormData()
      fd.append('avatar', blob, 'avatar.jpg')
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      if (csrf) fd.append('authenticity_token', csrf)

      const action = this.hasFormTarget ? this.formTarget.action : window.location.href
      fetch(action, { method: 'POST', body: fd })
        .then(() => {
          sessionStorage.removeItem('gm_avatar_src')
          window.location.href = this.cancelPathValue
        })
        .catch(() => {
          window.location.href = this.cancelPathValue
        })
    }, 'image/jpeg', 0.92)
  }

  cancel(event) {
    if (event) event.preventDefault()
    this.dispatch("cancel")

    if (this.cancelPathValue) {
      window.location.href = this.cancelPathValue
    } else if (window.history.length > 1) {
      window.history.back()
    }
  }
}
