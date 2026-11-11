import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state", "city"]
  static values  = { currentCity: String }

  connect() {
    if (this.stateTarget.value) this.fetchCities()
  }

  async fetchCities() {
    const uf = this.stateTarget.value  // value já é a sigla UF (ex: "BA")

    this.cityTarget.innerHTML = '<option value="">Carregando...</option>'
    this.cityTarget.disabled  = true

    if (!uf) {
      this.cityTarget.innerHTML = '<option value="">Cidade</option>'
      return
    }

    try {
      const res   = await fetch(`https://servicodados.ibge.gov.br/api/v1/localidades/estados/${uf}/municipios`)
      const data  = await res.json()
      const names = data.map(c => c.nome).sort((a, b) => a.localeCompare(b, "pt-BR"))

      const opts = names.map(name => {
        const selected = name === this.currentCityValue ? ' selected' : ''
        return `<option value="${name}"${selected}>${name}</option>`
      }).join("")

      this.cityTarget.innerHTML = `<option value="">Cidade</option>${opts}`
      this.cityTarget.disabled  = false
    } catch (err) {
      console.warn("[LocationFilter] Erro ao consultar IBGE:", err)
      this.cityTarget.innerHTML = '<option value="">Erro ao carregar</option>'
      this.cityTarget.disabled  = true
    }
  }
}
