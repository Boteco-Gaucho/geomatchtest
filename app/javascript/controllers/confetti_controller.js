import { Controller } from "@hotwired/stimulus"
import { launchConfetti } from "../confetti_animation.js"

export default class extends Controller {
  connect() {
    // Só dispara se a URL tiver ?match=true
    const params = new URLSearchParams(window.location.search)
    if (params.get("match") === "true") {
      launchConfetti()
    }
  }
}
