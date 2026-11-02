import { Controller } from "@hotwired/stimulus"

// Carrossel "Planos" de Meu Perfil: a bolinha ativa acompanha o card visível.
export default class extends Controller {
  static targets = ["track", "dot"]

  sync() {
    const cards = this.hasTrackTarget ? this.trackTarget.children : []
    if (cards.length === 0 || this.dotTargets.length === 0) return

    // Distância entre o início de um card e o do próximo (largura + espaço)
    const step = cards.length > 1 ? cards[1].offsetLeft - cards[0].offsetLeft : cards[0].offsetWidth
    const index = Math.min(this.dotTargets.length - 1, Math.max(0, Math.round(this.trackTarget.scrollLeft / step)))

    this.dotTargets.forEach((dot, i) => dot.classList.toggle("is-active", i === index))
  }
}
