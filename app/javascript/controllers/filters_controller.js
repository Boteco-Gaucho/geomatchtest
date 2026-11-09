import { Controller } from "@hotwired/stimulus"

// Folha "Filtros" da tela de início (/lead — users/lead.html.erb, LeadFilters no servidor).
// Enquanto a pessoa mexe: valores ("até 500 km", "18 – 60 anos"), preenchimento dos
// trilhos, as duas pontas da idade sem se cruzar, "N selecionados" e o selo "N ativos"
// (o que está diferente do padrão — os mesmos critérios de LeadFilters#active_count).
// "Aplicar filtros" envia o formulário; o servidor grava na sessão.
export default class extends Controller {
  static targets = ["modal", "form", "activeBadge", "gender", "distance", "distanceValue", "distanceRange",
                    "minAge", "maxAge", "ageValue", "ageRange", "interest", "interestsCount", "toggle"]
  static values = { defaultGenders: Array, defaultDistance: Number, defaultMinAge: Number, defaultMaxAge: Number }

  connect() {
    if (this.hasFormTarget) this.refresh()
  }

  open(event) {
    event?.preventDefault()
    this.modalTarget.classList.remove("hidden")
    document.documentElement.classList.add("lf-lock")
    this.refresh()
  }

  close(event) {
    event?.preventDefault()
    this.modalTarget.classList.add("hidden")
    document.documentElement.classList.remove("lf-lock")
  }

  disconnect() {
    document.documentElement.classList.remove("lf-lock")
  }

  refresh(event) {
    this.keepAgesApart(event?.target)

    // Distância
    const distance = parseInt(this.distanceTarget.value, 10)
    this.distanceValueTarget.textContent = distance
    this.paint(this.distanceRangeTarget, 0, this.percent(this.distanceTarget))

    // Idade
    const min = parseInt(this.minAgeTarget.value, 10)
    const max = parseInt(this.maxAgeTarget.value, 10)
    this.ageValueTarget.textContent = `${min} – ${max}`
    this.paint(this.ageRangeTarget, this.percent(this.minAgeTarget), this.percent(this.maxAgeTarget))

    // Interesses
    const interests = this.interestTargets.filter((i) => i.checked).length
    this.interestsCountTarget.hidden = interests === 0
    this.interestsCountTarget.textContent = `${interests} ${interests === 1 ? "selecionado" : "selecionados"}`

    // Selo "N ativos"
    const genders = this.genderTargets.filter((g) => g.checked).map((g) => g.value).sort()
    const active = [
      genders.join() !== [...this.defaultGendersValue].sort().join(),
      distance !== this.defaultDistanceValue,
      min !== this.defaultMinAgeValue || max !== this.defaultMaxAgeValue,
      interests > 0,
      ...this.toggleTargets.map((t) => t.checked)
    ].filter(Boolean).length
    this.activeBadgeTarget.hidden = active === 0
    this.activeBadgeTarget.textContent = `${active} ${active === 1 ? "ativo" : "ativos"}`
  }

  // A ponta que a pessoa arrasta não passa da outra
  keepAgesApart(moved) {
    const min = parseInt(this.minAgeTarget.value, 10)
    const max = parseInt(this.maxAgeTarget.value, 10)
    if (min <= max) return
    if (moved === this.maxAgeTarget) this.maxAgeTarget.value = min
    else this.minAgeTarget.value = max
  }

  percent(input) {
    const min = parseFloat(input.min)
    const max = parseFloat(input.max)
    return ((parseFloat(input.value) - min) / (max - min)) * 100
  }

  // Trilho preenchido entre from% e to% (variáveis lidas pelo CSS)
  paint(range, from, to) {
    range.style.setProperty("--lf-from", `${from}%`)
    range.style.setProperty("--lf-to", `${to}%`)
  }
}
