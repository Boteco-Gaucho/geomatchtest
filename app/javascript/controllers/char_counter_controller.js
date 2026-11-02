import { Controller } from "@hotwired/stimulus"

// Contador "58/300" da bio em Editar Perfil (o limite é o maxlength do campo)
export default class extends Controller {
  static targets = ["input", "count"]

  connect() {
    this.update()
  }

  update() {
    this.countTarget.textContent = `${this.inputTarget.value.length}/${this.inputTarget.maxLength}`
  }
}
