import { Controller } from "@hotwired/stimulus"

// Auto-submete o form da galeria quando o usuário troca sexo, estado ou cidade.
// Reseta a cidade ao trocar o estado, para evitar combinações inválidas.
export default class extends Controller {
  submit(event) {
    const el = event.target
    const form = this.element

    if (el.name === "estado") {
      const cidadeSel = form.querySelector('select[name="cidade"]')
      if (cidadeSel) cidadeSel.value = ""
    }

    form.requestSubmit()
  }
}
