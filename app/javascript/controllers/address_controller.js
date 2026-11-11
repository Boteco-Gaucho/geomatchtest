import { Controller } from "@hotwired/stimulus"

// Busca endereço na API ViaCEP e preenche os campos automaticamente.
// Uso: data-controller="address" no elemento pai dos campos.
export default class extends Controller {
  static targets = ["zipCode", "street", "neighborhood", "city", "state", "feedback"]

  async lookup() {
    const cep = this.zipCodeTarget.value.replace(/\D/g, "")

    this.clearFeedback()
    this.clearFields()

    if (cep.length !== 8) {
      if (cep.length > 0) this.showError("Digite um CEP com 8 dígitos.")
      return
    }

    try {
      const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`)

      if (!response.ok) {
        this.showError("Erro ao consultar o CEP. Tente novamente.")
        return
      }

      const data = await response.json()

      if (data.erro) {
        this.showError("CEP não encontrado. Verifique e tente novamente.")
        return
      }

      this.streetTarget.value       = data.logradouro || ""
      this.neighborhoodTarget.value = data.bairro     || ""
      this.cityTarget.value         = data.localidade || ""
      this.stateTarget.value        = data.uf         || ""

    } catch (_error) {
      this.showError("Falha na conexão ao buscar o CEP. Tente novamente.")
    }
  }

  // --- Helpers ---

  clearFields() {
    this.streetTarget.value       = ""
    this.neighborhoodTarget.value = ""
    this.cityTarget.value         = ""
    this.stateTarget.value        = ""
  }

  clearFeedback() {
    if (this.hasFeedbackTarget) this.feedbackTarget.textContent = ""
  }

  showError(message) {
    if (this.hasFeedbackTarget) this.feedbackTarget.textContent = message
  }
}
