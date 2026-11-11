// app/javascript/controllers/landing_controller.js
// GeoMatch — Landing Page
// - Reveal on scroll: scroll event (primário) + IntersectionObserver (complemento)
// - Marquee: duplica conteúdo para loop contínuo
// - Hero: paralaxe no scroll + tilt 3D no mockup (desktop)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.motionOK = window.matchMedia("(prefers-reduced-motion: no-preference)").matches
    this.setupMarquees()
    this.setupReveal()
    this.setupMobileCta()
    this.setupHeroMotion()
    this.setupHorizontalLock()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
    if (this._revealOnScroll) {
      window.removeEventListener("scroll", this._revealOnScroll)
      window.removeEventListener("touchmove", this._revealOnScroll)
    }
    if (this._onTouchStart) document.removeEventListener("touchstart", this._onTouchStart)
    if (this._onTouchMove)  document.removeEventListener("touchmove",  this._onTouchMove)
  }

  // Duplica o conteúdo das faixas para o loop ser contínuo
  setupMarquees() {
    this.element.querySelectorAll(".marquee-track").forEach((track) => {
      if (track.dataset.duplicated) return
      track.innerHTML += track.innerHTML
      track.dataset.duplicated = "true"
    })
  }

  // Revela .rv à medida que entram na viewport.
  // Usa scroll event como mecanismo primário (funciona em todos os browsers mobile reais)
  // e IntersectionObserver como complemento para eficiência em desktop.
  setupReveal() {
    const all = Array.from(this.element.querySelectorAll(".rv"))
    if (all.length === 0) return

    const reveal = (el) => {
      if (el._revealed) return
      el._revealed = true
      el.classList.add("is-in")
    }

    const inViewport = (el) => {
      const r = el.getBoundingClientRect()
      return r.top < window.innerHeight - 20 && r.bottom > 0
    }

    // --- Scroll fallback (mecanismo primário para mobile real) ---
    // getBoundingClientRect é calculado em relação ao viewport, sem depender
    // de scroll container — funciona independente de qualquer overflow setting.
    let pending = [...all]
    const checkAll = () => {
      pending = pending.filter((el) => {
        if (inViewport(el)) { reveal(el); return false }
        return true
      })
      if (pending.length === 0) {
        window.removeEventListener("scroll", this._revealOnScroll)
        window.removeEventListener("touchmove", this._revealOnScroll)
        this._revealOnScroll = null
      }
    }
    this._revealOnScroll = checkAll
    window.addEventListener("scroll", this._revealOnScroll, { passive: true })
    window.addEventListener("touchmove", this._revealOnScroll, { passive: true })
    // Verifica elementos já visíveis no load (above the fold)
    checkAll()

    // --- IntersectionObserver como complemento (mais eficiente em desktop) ---
    if (!("IntersectionObserver" in window)) return
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            reveal(entry.target)
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0, rootMargin: "0px" }
    )
    all.forEach((el) => this.observer.observe(el))
  }

  // CTA fixo mobile: aparece após o hero, some perto do CTA final
  setupMobileCta() {
    const bar = this.element.querySelector("#mobile-cta")
    if (!bar) return

    const sync = () => {
      const show = this._pastHero && !this._nearEnd
      bar.classList.toggle("is-visible", show)
      bar.setAttribute("aria-hidden", show ? "false" : "true")
    }
    this._pastHero = false
    this._nearEnd = false

    const hero = this.element.querySelector(".hero")
    const end = this.element.querySelector("#baixar")

    if ("IntersectionObserver" in window) {
      if (hero) new IntersectionObserver((en) => { this._pastHero = !en[0].isIntersecting; sync() }, { threshold: 0.05 }).observe(hero)
      if (end) new IntersectionObserver((en) => { this._nearEnd = en[0].isIntersecting; sync() }, { threshold: 0.12 }).observe(end)
    } else {
      // fallback: scroll simples
      window.addEventListener("scroll", () => {
        if (hero) this._pastHero = hero.getBoundingClientRect().bottom < 0
        if (end) this._nearEnd = end.getBoundingClientRect().top < window.innerHeight
        sync()
      }, { passive: true })
    }
  }

  // Paralaxe + tilt 3D no mockup do hero (apenas desktop com cursor)
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

  // Bloqueia rubber-band horizontal no iOS Safari.
  // CSS (touch-action, overscroll-behavior) não é suficiente em versões antigas —
  // preventDefault() no touchmove é a única garantia universal.
  setupHorizontalLock() {
    let startX = 0, startY = 0

    this._onTouchStart = (e) => {
      if (e.touches.length !== 1) return
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }

    this._onTouchMove = (e) => {
      if (e.touches.length !== 1) return
      const dx = Math.abs(e.touches[0].clientX - startX)
      const dy = Math.abs(e.touches[0].clientY - startY)
      // Bloqueia somente quando o gesto é predominantemente horizontal
      if (dx > dy && dx > 5) e.preventDefault()
    }

    document.addEventListener("touchstart", this._onTouchStart, { passive: true })
    // passive: false obrigatório para que preventDefault() funcione
    document.addEventListener("touchmove", this._onTouchMove, { passive: false })
  }
}
