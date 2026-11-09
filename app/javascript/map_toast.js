// Aviso em pílula no topo (#map-toast — partial shared/_map_toast): ícone, título, texto
// e, opcionalmente, um botão (ex.: "Ver Gold"). Tocar fora do botão fecha.
// Usado no mapa (map_3d.js: tempo real, modo oculto) e em Meu Perfil (o interruptor
// "Modo oculto" — visibility_toggle_controller.js), com os mesmos textos.
// Estilos .map-toast* em discover.scss.

export const MAP_TOAST_ICONS = {
  nav: '<polygon points="3 11 22 2 13 21 11 13 3 11"/>',
  navOff: '<path d="M8.43 8.43 3 11l8 2 2 8 2.57-5.43"/><path d="M17.39 11.73 22 2l-9.73 4.61"/><path d="M2 2l20 20"/>',
  ghost: '<path d="M9 10h.01M15 10h.01"/><path d="M12 2a8 8 0 0 0-8 8v12l3-3 2.5 2.5L12 19l2.5 2.5L17 19l3 3V10a8 8 0 0 0-8-8z"/>',
  eye: '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>',
  heart: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
  heartOff: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/><path d="M3 3l18 18"/>',
  eyeOff: '<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><path d="M1 1l22 22"/>'
};

export const MAP_TOASTS = {
  trackingOn:  { icon: "nav",    tone: "green", title: "Visibilidade em tempo real ativada",   text: "Prepare-se para encontros espontâneos." },
  trackingOff: { icon: "navOff", tone: "sand",  title: "Visibilidade em tempo real desativada", text: "Sua localização não está mais visível." },
  hiddenOn:    { icon: "eyeOff", tone: "dark",  title: "Modo oculto ativado",   text: "Você vê todo mundo sem aparecer no mapa." },
  hiddenOff:   { icon: "eye",    tone: "green", title: "Modo oculto desativado", text: "Você voltou a aparecer no mapa." },
  goldOnly:    { icon: "ghost",  tone: "dark",  title: "Modo oculto é do Gold", text: "Veja todo mundo sem ser visto.", duration: 6000 }
};

export function showMapToast({ icon, tone, title, text, action = null, duration = 3500 }) {
  const toast = document.getElementById("map-toast");
  if (!toast) return;

  toast.querySelector(".map-toast__icon").innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true">${MAP_TOAST_ICONS[icon] || ""}</svg>`;
  toast.querySelector(".map-toast__icon").dataset.tone = tone;
  toast.querySelector(".map-toast__title").textContent = title;
  toast.querySelector(".map-toast__body").textContent = text;

  const button = toast.querySelector(".map-toast__action");
  button.hidden = !action;
  button.textContent = action ? action.label : "";
  button.onclick = action ? (e) => { e.stopPropagation(); hideMapToast(); action.onClick(); } : null;
  toast.onclick = hideMapToast;

  toast.hidden = false;
  toast.classList.remove("is-visible");
  void toast.offsetWidth; // reinicia a animação de entrada se já estava aberto
  toast.classList.add("is-visible");

  clearTimeout(window._mapToastTimer);
  window._mapToastTimer = setTimeout(hideMapToast, duration);
}

export function hideMapToast() {
  const toast = document.getElementById("map-toast");
  if (!toast || toast.hidden) return;
  clearTimeout(window._mapToastTimer);
  toast.classList.remove("is-visible");
  window._mapToastTimer = setTimeout(() => { toast.hidden = true; }, 200);
}
