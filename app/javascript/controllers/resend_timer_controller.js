import { Controller } from "@hotwired/stimulus"

// "Reenviar link em 1:00" da tela Link enviado! (devise/passwords/sent): conta os segundos
// que o servidor mandou (a partir do último envio) e libera o botão no fim.
export default class extends Controller {
  static targets = ["button", "label"]
  static values = { seconds: Number }

  connect() {
    this.remaining = this.secondsValue
    this.render()
    if (this.remaining > 0) this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    this.remaining -= 1
    if (this.remaining <= 0) clearInterval(this.timer)
    this.render()
  }

  render() {
    const waiting = this.remaining > 0
    this.buttonTarget.disabled = waiting
    if (waiting) {
      const minutes = Math.floor(this.remaining / 60)
      const seconds = String(this.remaining % 60).padStart(2, "0")
      this.labelTarget.textContent = `Reenviar link em ${minutes}:${seconds}`
    } else {
      this.labelTarget.textContent = "Reenviar link"
    }
  }
}
