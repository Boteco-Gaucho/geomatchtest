import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "map"]
  static values  = {
    minDuration: { type: Number, default: 600 },
    autoTimeout: { type: Number, default: 15000 }
  }

  connect() {
    this.startedAt = performance.now()
    this.element.addEventListener("map:loaded", this.hide)
    this.timeoutId = setTimeout(this.hide, this.autoTimeoutValue)

    // Restore the overlay in the DOM snapshot BEFORE Turbo caches the page.
    // Without this, the snapshot would have the overlay removed/hidden, causing
    // a flash of the raw map if the cached version were ever shown as a preview.
    this._onBeforeCache = this._restoreOverlay.bind(this)
    document.addEventListener("turbo:before-cache", this._onBeforeCache)
  }

  disconnect() {
    this.element.removeEventListener("map:loaded", this.hide)
    clearTimeout(this.timeoutId)
    document.removeEventListener("turbo:before-cache", this._onBeforeCache)
  }

  hide = () => {
    if (!this.hasOverlayTarget) return
    const elapsed   = performance.now() - this.startedAt
    const remaining = Math.max(0, this.minDurationValue - elapsed)

    setTimeout(() => {
      this.overlayTarget.classList.add("is-loaded")
      // Use a CSS class to hide instead of remove() so the element stays in the
      // DOM and can be restored when Turbo fires turbo:before-cache.
      setTimeout(() => this.overlayTarget.classList.add("hidden"), 500)
    }, remaining)

    clearTimeout(this.timeoutId)
  }

  _restoreOverlay() {
    if (!this.hasOverlayTarget) return
    // Strip both the fade-out and the hide classes so the overlay is fully
    // visible in the Turbo cache snapshot.
    this.overlayTarget.classList.remove("is-loaded", "hidden")
  }
}
