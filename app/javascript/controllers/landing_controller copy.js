// app/javascript/controllers/landing_controller.js
// GeoMatch — Landing Page
// - Reveal on scroll (IntersectionObserver)
// - Marquee: duplica o conteúdo para loop contínuo
// - Hero: paralaxe no scroll + tilt 3D no mockup (desktop)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.motionOK = window.matchMedia("(prefers-reduced-motion: no-preference)").matches
    this.setupMarquees()
    this.setupReveal()
    this.setupMobileCta()
    this.setupHeroMotion()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
  }

  // Duplica o conteúdo das faixas para o loop ser contínuo
  setupMarquees() {
    this.element.querySelectorAll(".marquee-track").forEach((track) => {
      if (track.dataset.duplicated) return
      track.innerHTML += track.innerHTML
      track.dataset.duplicated = "true"
    })
  }

  // Revela elementos .rv conforme entram na viewport
  setupReveal() {
    const els = this.element.querySelectorAll(".rv")
    if (!("IntersectionObserver" in window)) {
      els.forEach((el) => el.classList.add("is-in"))
      return
    }
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.12, rootMargin: "0px 0px -6% 0px" }
    )
    els.forEach((el) => this.observer.observe(el))
  }

  // CTA fixo mobile: aparece após o hero, some perto do CTA final
  setupMobileCta() {
    const bar = this.element.querySelector("#mobile-cta")
    if (!bar || !("IntersectionObserver" in window)) return
    let pastHero = false, nearEnd = false
    const sync = () => {
      const show = pastHero && !nearEnd
      bar.classList.toggle("is-visible", show)
      bar.setAttribute("aria-hidden", show ? "false" : "true")
    }
    const hero = this.element.querySelector(".hero")
    const end = this.element.querySelector("#baixar")
    if (hero) new IntersectionObserver((en) => { pastHero = !en[0].isIntersecting; sync() }, { threshold: 0.05 }).observe(hero)
    if (end) new IntersectionObserver((en) => { nearEnd = en[0].isIntersecting; sync() }, { threshold: 0.12 }).observe(end)
  }

  // Paralaxe + tilt 3D no mockup do hero
  setupHeroMotion() {
    const hero = this.element.querySelector(".hero")
    const phone = this.element.querySelector(".hero .phone")
    const pointerFine = window.matchMedia("(pointer: fine)").matches
    if (!this.motionOK || !pointerFine || !hero || !phone) return

    let py = 0, rx = 0, ry = 0, raf = null
    const apply = () => {
      raf = null
      phone.style.transform =
        `translateY(${py.toFixed(1)}px) perspective(900px) ` +
        `rotateX(${rx.toFixed(2)}deg) rotateY(${ry.toFixed(2)}deg)`
    }
    const schedule = () => { if (!raf) raf = requestAnimationFrame(apply) }

    this.onScroll = () => {
      const y = window.scrollY
      if (y > window.innerHeight * 1.3) return
      py = y * -0.07
      schedule()
    }
    window.addEventListener("scroll", this.onScroll, { passive: true })

    hero.addEventListener("mousemove", (e) => {
      const r = hero.getBoundingClientRect()
      ry = ((e.clientX - r.left) / r.width - 0.5) * 7
      rx = -((e.clientY - r.top) / r.height - 0.5) * 5
      schedule()
    })
    hero.addEventListener("mouseleave", () => { rx = 0; ry = 0; schedule() })
  }
}
