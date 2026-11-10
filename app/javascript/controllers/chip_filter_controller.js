import { Controller } from "@hotwired/stimulus"

// Profissão no Editar perfil: a busca esconde os chips que não batem (sem acento e sem
// maiúsculas) e escrever em "Não achou? Escreva aqui" desmarca o chip escolhido.
export default class extends Controller {
  static targets = ["query", "empty", "other"]

  filter() {
    const term = this.normalize(this.queryTarget.value)
    let shown = 0
    this.element.querySelectorAll(".pe-chip[data-chip-label]").forEach((chip) => {
      const match = !term || this.normalize(chip.dataset.chipLabel).includes(term)
      chip.hidden = !match
      if (match) shown++
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }

  typed() {
    if (!this.otherTarget.value.trim()) return
    this.element.querySelectorAll("input[type=radio]").forEach((radio) => { radio.checked = false })
  }

  normalize(text) {
    return (text || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim()
  }
}
