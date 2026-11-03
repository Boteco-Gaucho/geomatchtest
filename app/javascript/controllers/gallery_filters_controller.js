import { Controller } from "@hotwired/stimulus"

// Auto-submete o form da galeria quando o usuário troca sexo, estado ou cidade.
// Reseta a cidade ao trocar o estado, para evitar combinações inválidas.
export default class extends Controller {
  submit(event) {
    const el = event.target
    const form = this.element

    if (el.name === "state") {
      const citySelect = form.querySelector('select[name="city"]')
      if (citySelect) citySelect.value = ""
    }

    form.requestSubmit()
  }
}
