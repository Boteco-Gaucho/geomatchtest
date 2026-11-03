// Modal de planos (ex.: "Ver Gold" do modo oculto): busca /plans/modal, injeta no
// #upgrade-modal-container da página e liga os fechamentos
export async function openUpgradeModal(type = "invisible") {
  const container = document.getElementById("upgrade-modal-container")
  if (!container) return

  const response = await fetch(`/plans/modal?type=${encodeURIComponent(type)}`)
  container.innerHTML = await response.text()

  const backdrop = container.querySelector(".upgrade-modal-backdrop")
  const close = () => {
    if (!backdrop) return
    backdrop.style.opacity = "0"
    setTimeout(() => { container.innerHTML = "" }, 300)
  }
  container.querySelectorAll(".close-modal-btn").forEach((button) => {
    button.onclick = (event) => { event.preventDefault(); close() }
  })
  if (backdrop) backdrop.onclick = (event) => { if (event.target === backdrop) close() }
}
