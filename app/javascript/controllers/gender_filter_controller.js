import { Controller } from "@hotwired/stimulus"

// Filtro de gênero segmentado do mapa 3D (partial users/_gender_filter).
//
// Os valores do partial (men/women/non_binary) são traduzidos aqui para as
// chaves canônicas que o DiscoveryService/map_3d.js entendem (male/female/
// non-binary) — valores fora desse contrato são ignorados pelo backend.
//
// A comunicação com o map_3d.js é desacoplada via CustomEvent no document:
// o mapa escuta "gm:gender-changed" e refaz o fetch de usuários próximos.
const VALUE_MAP = {
  all:        "all",
  men:        "male",
  women:      "female",
  non_binary: "non-binary",
}

export default class extends Controller {
  static targets = ["option"]
  static values  = { selected: String }

  select(event) {
    const btn   = event.currentTarget
    const value = btn.dataset.value
    if (value === this.selectedValue) return

    this.selectedValue = value
    this.optionTargets.forEach(opt => {
      opt.setAttribute("aria-pressed", (opt.dataset.value === value).toString())
    })

    document.dispatchEvent(new CustomEvent("gm:gender-changed", {
      detail: {
        key:   VALUE_MAP[value] || "all",
        label: btn.dataset.label || btn.title,
      }
    }))
  }
}
