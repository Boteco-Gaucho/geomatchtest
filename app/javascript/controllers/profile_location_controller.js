import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state", "city"]

  connect() {
    // Se o perfil já tem estado salvo, pré-carrega as cidades para autocomplete
    if (this.stateTarget.value) this.fetchCities()
  }

  async fetchCities() {
    const uf = this.stateTarget.value

    if (!uf) {
      this.clearCities()
      return
    }

    try {
      const res   = await fetch(`https://servicodados.ibge.gov.br/api/v1/localidades/estados/${uf}/municipios`)
      const data  = await res.json()
      const names = data.map(c => c.nome).sort((a, b) => a.localeCompare(b, "pt-BR"))

      const datalist = document.getElementById("profile-cities-list")
      if (!datalist) return

      datalist.innerHTML       = names.map(n => `<option value="${n}"></option>`).join("")
      this.cityTarget.disabled = false
    } catch (err) {
      console.warn("[ProfileLocation] Erro ao consultar IBGE:", err)
    }
  }

  clearCities() {
    const datalist = document.getElementById("profile-cities-list")
    if (datalist) datalist.innerHTML = ""
    this.cityTarget.value    = ""
    this.cityTarget.disabled = true
  }
}
