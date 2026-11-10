import { Controller } from "@hotwired/stimulus"

// Altura no Editar perfil: o chip "Prefiro não informar" escolhe a opção 0 da lista (e
// tocar de novo volta para "Escolha"); escolher uma altura desmarca o chip.
export default class extends Controller {
  static targets = ["select", "chip"]

  toggle() {
    this.selectTarget.value = this.selectTarget.value === "0" ? "" : "0"
    this.sync()
  }

  sync() {
    this.chipTarget.setAttribute("aria-pressed", String(this.selectTarget.value === "0"))
  }
}
