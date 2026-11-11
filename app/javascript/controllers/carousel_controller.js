import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slides", "indicator"]

  connect() {
    this._onScroll = this._handleScroll.bind(this)
    if (this.hasSlidesTarget) {
      this.slidesTarget.addEventListener("scroll", this._onScroll, { passive: true })
    }
  }

  disconnect() {
    if (this.hasSlidesTarget) {
      this.slidesTarget.removeEventListener("scroll", this._onScroll)
    }
  }

  prev(event) {
    if (event) { event.stopPropagation(); event.preventDefault() }
    if (!this.hasSlidesTarget) return
    const el    = this.slidesTarget
    const index = Math.round(el.scrollLeft / Math.max(el.clientWidth, 1))
    if (index <= 0) return
    el.scrollTo({ left: (index - 1) * el.clientWidth, behavior: "smooth" })
  }

  next(event) {
    if (event) { event.stopPropagation(); event.preventDefault() }
    if (!this.hasSlidesTarget) return
    const el    = this.slidesTarget
    const count = el.querySelectorAll(".pc-slide").length
    const index = Math.round(el.scrollLeft / Math.max(el.clientWidth, 1))
    if (index >= count - 1) return
    el.scrollTo({ left: (index + 1) * el.clientWidth, behavior: "smooth" })
  }

  _handleScroll() {
    if (!this.hasSlidesTarget) return
    const el    = this.slidesTarget
    const index = Math.round(el.scrollLeft / Math.max(el.clientWidth, 1))
    this.indicatorTargets.forEach((d, i) =>
      d.classList.toggle("pc-indicator--active", i === index)
    )
  }
}
