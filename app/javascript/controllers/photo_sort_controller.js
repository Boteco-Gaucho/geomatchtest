import { Controller } from "@hotwired/stimulus"

// Fotos de Editar Perfil: segurar e arrastar muda a ordem das fotos do álbum
// (posições 2 a 6). Cada foto leva um input hidden user[album_order][], então a
// ordem do DOM é a ordem enviada no "Salvar".
const HOLD_MS = 250 // tempo segurando até a foto "soltar" para arrastar
const SLOP_PX = 8   // mexer mais que isso antes disso é rolagem, não arraste

export default class extends Controller {
  static targets = ["photo", "number"]

  connect() {
    // passive: false — sem isso o iOS rola a página junto com a foto arrastada
    this.blockScroll = (event) => { if (this.dragging) event.preventDefault() }
    this.element.addEventListener("touchmove", this.blockScroll, { passive: false })
  }

  disconnect() {
    this.element.removeEventListener("touchmove", this.blockScroll)
    this.reset()
  }

  press(event) {
    if (!event.isPrimary || event.button !== 0 || event.target.closest("a, button")) return

    const tile = event.currentTarget
    this.pointerId = event.pointerId
    this.start = { x: event.clientX, y: event.clientY }
    this.timer = setTimeout(() => this.lift(tile), HOLD_MS)
  }

  move(event) {
    if (event.pointerId !== this.pointerId) return

    const dx = event.clientX - this.start.x
    const dy = event.clientY - this.start.y

    if (!this.dragging) {
      if (Math.hypot(dx, dy) > SLOP_PX) this.reset()
      return
    }

    this.tile.style.transform = `translate(${dx}px, ${dy}px) scale(1.05)`
    const target = this.photoAt(event.clientX, event.clientY)
    this.photoTargets.forEach(photo => photo.classList.toggle("is-drop-target", photo === target))
  }

  release(event) {
    if (event.pointerId !== this.pointerId) return

    if (this.dragging && event.type === "pointerup") {
      const target = this.photoAt(event.clientX, event.clientY)
      if (target) this.drop(target)
    }
    this.reset()
  }

  // Segurar a foto não abre o menu de "salvar imagem" do celular
  suppress(event) {
    event.preventDefault()
  }

  lift(tile) {
    this.dragging = true
    this.tile = tile
    tile.classList.add("is-dragging")
    try { tile.setPointerCapture(this.pointerId) } catch (_) {}
    navigator.vibrate?.(10)
  }

  // Solta antes ou depois da foto alvo, empurrando as do meio (como reordenar uma lista)
  drop(target) {
    const photos = this.photoTargets
    target[photos.indexOf(this.tile) < photos.indexOf(target) ? "after" : "before"](this.tile)
    this.numberTargets.forEach((number, index) => { number.textContent = index + 2 })
  }

  photoAt(x, y) {
    return this.photoTargets.find(photo => {
      if (photo === this.tile) return false
      const rect = photo.getBoundingClientRect()
      return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom
    })
  }

  reset() {
    clearTimeout(this.timer)
    if (this.tile) {
      this.tile.classList.remove("is-dragging")
      this.tile.style.transform = ""
    }
    this.photoTargets.forEach(photo => photo.classList.remove("is-drop-target"))
    this.dragging = false
    this.tile = null
    this.pointerId = null
  }
}
