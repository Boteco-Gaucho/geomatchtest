import { Controller } from "@hotwired/stimulus"

const TRACK_DARK  = "#2a2a2e"
const TRACK_LIGHT = "#dcdce0"

export default class extends Controller {
  static targets = ["modal", "distanceValue", "distanceInput", "minAgeInput", "maxAgeInput", "ageDisplay"]

  connect() {
    this.updateDistanceVisual()
    this.updateAgeVisual()
  }

  open(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
  }

  updateDistanceVisual() {
    if (this.hasDistanceInputTarget) {
      this.distanceValueTarget.textContent = this.distanceInputTarget.value
      this._paintSlider(this.distanceInputTarget)
    }
  }

  updateAgeVisual() {
    if (this.hasMinAgeInputTarget && this.hasMaxAgeInputTarget) {
      const min = parseInt(this.minAgeInputTarget.value)
      const max = parseInt(this.maxAgeInputTarget.value)
      this.ageDisplayTarget.textContent = `${min} - ${max}`
      this._paintSlider(this.minAgeInputTarget)
      this._paintSlider(this.maxAgeInputTarget)
    }
  }

  _paintSlider(input) {
    const min = parseFloat(input.min) || 0
    const max = parseFloat(input.max) || 100
    const val = parseFloat(input.value)
    const pct = ((val - min) / (max - min)) * 100
    const html = document.documentElement
    const isDark = html.classList.contains("dark-mode") || (html.classList.contains("dark") && !html.classList.contains("light-mode"))
    const trackBg = isDark ? TRACK_DARK : TRACK_LIGHT
    input.style.background =
      `linear-gradient(to right, #F4DFC4 0%, #C9A079 ${pct}%, ${trackBg} ${pct}%, ${trackBg} 100%)`
  }
}
