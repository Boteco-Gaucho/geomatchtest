import { Controller } from "@hotwired/stimulus"

// Cobre as 3 telas da carteira (Fase 4 + Fase 5.2):
//   Carteira  — saldo (/wallet) + extrato (/wallet/transactions)
//   Saque     — envia POST /wallet/withdraw com valor + chave Pix
//   Depósito  — envia POST /wallet/deposit e redireciona ao checkout do Mercado Pago
export default class extends Controller {
  static targets = [
    "balance", "reserved", "history", "filter",                                        // carteira
    "amountInput", "availableText", "keyOptions", "keyInput", "error", "withdrawButton", // saque
    "depositAmountInput", "depositError", "depositButton"                              // depósito
  ]

  static values = {
    showUrl: String,
    transactionsUrl: String,
    withdrawUrl: String,
    withdrawPageUrl: String,
    walletPageUrl: String,
    depositUrl: String,
    reconcileUrl: String
  }

  selectedKeyType = null
  entries = null       // extrato carregado (carteira)
  historyFilter = "all" // Tudo / Entradas / Saídas

  connect() {
    this.load()
  }

  // Em série, não em paralelo: GET /wallet concilia os depósitos pendentes contra
  // o Mercado Pago antes de responder, e o extrato precisa ser lido DEPOIS disso —
  // senão o saldo aparece atualizado e o histórico ainda vem sem o depósito.
  async load() {
    if (this.returningFromCheckout() && this.hasReconcileUrlValue) {
      await this.forceReconcile()
    }

    if (this.hasBalanceTarget || this.hasAmountInputTarget) await this.loadWallet()
    if (this.hasHistoryTarget) await this.loadTransactions()
  }

  returningFromCheckout() {
    const deposito = new URLSearchParams(window.location.search).get("deposito")
    return deposito === "success" || deposito === "pending"
  }

  // Conciliação explícita: ignora o throttle do servidor. Vale a pena no retorno
  // do checkout, quando o PIX pode ter compensado segundos atrás.
  async forceReconcile() {
    try {
      await fetch(this.reconcileUrlValue, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() }
      })
    } catch (e) {
      // A conciliação é reforço, não pré-requisito: seguimos para ler o saldo.
      console.error("[Wallet] reconcile falhou:", e)
    }
  }

  // ───────────────────────── CARTEIRA ─────────────────────────
  async loadWallet() {
    try {
      const wallet = await this.fetchJson(this.showUrlValue)

      // O card diz "Saldo disponível", então precisa mostrar o DISPONÍVEL, não o
      // total: um saque solicitado reserva o valor (pending_withdrawal_cents) e
      // só sai do balance quando o pagamento é confirmado. Mostrar o total aqui
      // fazia parecer que o pedido de saque não tinha surtido efeito nenhum.
      // Só o número: o "R$" fica à parte no card (pages/mimo_wallet.html.erb)
      if (this.hasBalanceTarget) {
        this.balanceTarget.textContent = this.formatNumber(wallet.available_balance_cents || 0)
      }

      // O valor reservado não some — ele fica explícito, aguardando o saque.
      if (this.hasReservedTarget) {
        const reserved = wallet.pending_withdrawal_cents || 0
        this.reservedTarget.textContent = reserved > 0
          ? `${this.formatCents(reserved)} reservado em saque solicitado`
          : ""
        this.reservedTarget.classList.toggle("is-visible", reserved > 0)
      }

      if (this.hasAvailableTextTarget) {
        this.availableTextTarget.textContent = this.formatCents(wallet.available_balance_cents || 0)
      }
      if (this.hasAmountInputTarget && wallet.available_balance_cents > 0) {
        this.amountInputTarget.value = this.formatCents(wallet.available_balance_cents)
      }
      if (this.hasKeyInputTarget && wallet.pix_key) {
        this.keyInputTarget.value = wallet.pix_key
        if (wallet.pix_key_type) this.applyKeyType(wallet.pix_key_type)
      }
    } catch (e) {
      console.error("[Wallet] loadWallet falhou:", e)
    }
  }

  async loadTransactions() {
    try {
      const data = await this.fetchJson(this.transactionsUrlValue)
      this.entries = data.transactions || []
      this.renderHistory()
    } catch (e) {
      this.historyTarget.innerHTML = this.emptyHtml("Não foi possível carregar o extrato.", "Verifique sua conexão e abra a carteira de novo.")
      console.error("[Wallet] loadTransactions falhou:", e)
    }
  }

  // Filtros Tudo / Entradas / Saídas (entrada = valor positivo)
  filterHistory(event) {
    this.historyFilter = event.currentTarget.dataset.filter
    this.filterTargets.forEach((btn) => {
      const active = btn.dataset.filter === this.historyFilter
      btn.classList.toggle("is-active", active)
      btn.setAttribute("aria-pressed", String(active))
    })
    if (this.entries) this.renderHistory()
  }

  renderHistory() {
    const entries = this.entries.filter((entry) => {
      if (this.historyFilter === "in") return entry.amount_cents >= 0
      if (this.historyFilter === "out") return entry.amount_cents < 0
      return true
    })

    if (!entries.length) {
      const [title, text] = {
        all: ["Nenhuma movimentação ainda", "Quando você adicionar ou sacar saldo, tudo aparece aqui."],
        in:  ["Nenhuma entrada ainda", "Saldo adicionado e mimos recebidos aparecem aqui."],
        out: ["Nenhuma saída ainda", "Seus saques via Pix aparecem aqui."]
      }[this.historyFilter]
      this.historyTarget.innerHTML = this.emptyHtml(title, text)
      return
    }

    this.historyTarget.innerHTML = `<ul class="wl-tx-list">${entries.map((entry) => {
      const isIn = entry.amount_cents >= 0
      const arrow = isIn ? '<path d="M12 19V5M6 11l6-6 6 6"/>' : '<path d="M12 5v14M6 13l6 6 6-6"/>'

      // status_label distingue "saque pago" de "saque só solicitado" — sem ele
      // um pedido pendente aparece idêntico a um pagamento já concluído.
      const status = entry.status_label
        ? ` <span class="wl-tx-status">· ${this.escapeHtml(entry.status_label)}</span>`
        : ""

      return `
        <li class="wl-tx">
          <span class="wl-tx-icon ${isIn ? "is-in" : "is-out"}" aria-hidden="true"><svg viewBox="0 0 24 24">${arrow}</svg></span>
          <span class="wl-tx-main">
            <strong>${this.escapeHtml(entry.description)}</strong>
            <small>${this.formatDate(entry.created_at)}${status}</small>
          </span>
          <span class="wl-tx-value ${isIn ? "is-in" : "is-out"}">${isIn ? "+" : "−"} ${this.formatCents(Math.abs(entry.amount_cents))}</span>
        </li>`
    }).join("")}</ul>`
  }

  emptyHtml(title, text) {
    return `
      <div class="wl-empty">
        <span class="wl-empty-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24"><path d="M6 3h12v18l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5L6 21z"/><path d="M9 8h6M9 12h6M9 16h3"/></svg>
        </span>
        <strong class="wl-empty-title">${this.escapeHtml(title)}</strong>
        <p class="wl-empty-text">${this.escapeHtml(text)}</p>
      </div>`
  }

  goToWithdraw() {
    if (this.hasWithdrawPageUrlValue) window.location.href = this.withdrawPageUrlValue
  }

  // ───────────────────────── SAQUE ─────────────────────────
  selectKeyType(event) {
    this.applyKeyType(event.currentTarget.dataset.keyType)
  }

  applyKeyType(keyType) {
    this.selectedKeyType = keyType
    this.keyOptionsTarget.querySelectorAll(".gm-saque-key-opt").forEach((opt) => {
      opt.classList.toggle("is-selected", opt.dataset.keyType === keyType)
    })
  }

  async withdraw() {
    this.hideError()

    const amountCents = this.parseAmountToCents(this.amountInputTarget.value)
    if (!amountCents || amountCents <= 0) {
      this.showError("Informe um valor válido para o saque.")
      return
    }

    const pixKey = this.hasKeyInputTarget ? this.keyInputTarget.value.trim() : ""
    if (!pixKey || !this.selectedKeyType) {
      this.showError("Selecione o tipo de chave e informe a chave Pix.")
      return
    }

    this.setLoading(true)

    try {
      const response = await fetch(this.withdrawUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ amount_cents: amountCents, pix_key: pixKey, pix_key_type: this.selectedKeyType })
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        this.showError(data.error || "Não foi possível processar o saque.")
        this.setLoading(false)
        return
      }

      window.location.href = this.hasWalletPageUrlValue ? this.walletPageUrlValue : "/carteira"
    } catch (e) {
      console.error("[Wallet] withdraw falhou:", e)
      this.showError("Falha de conexão. Verifique sua internet e tente novamente.")
      this.setLoading(false)
    }
  }

  // ───────────────────────── DEPÓSITO ─────────────────────────
  selectDepositPreset(event) {
    const cents = parseInt(event.currentTarget.dataset.amountCents, 10)
    if (this.hasDepositAmountInputTarget) this.depositAmountInputTarget.value = this.formatCents(cents)

    this.element.querySelectorAll(".gm-deposit-preset").forEach((btn) => {
      btn.classList.toggle("is-selected", parseInt(btn.dataset.amountCents, 10) === cents)
    })
    this.hideDepositError()
  }

  // Digitar um valor manualmente desmarca qualquer preset selecionado — o
  // input de texto é sempre a fonte de verdade do valor a depositar.
  clearDepositPreset() {
    this.element.querySelectorAll(".gm-deposit-preset").forEach((btn) => btn.classList.remove("is-selected"))
  }

  async deposit() {
    this.hideDepositError()

    const amountCents = this.hasDepositAmountInputTarget ? this.parseAmountToCents(this.depositAmountInputTarget.value) : 0
    if (!amountCents || amountCents < 500) {
      this.showDepositError("Informe um valor de pelo menos R$ 5,00.")
      return
    }

    this.setDepositLoading(true)

    try {
      const response = await fetch(this.depositUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ amount_cents: amountCents })
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        this.showDepositError(data.error || "Não foi possível iniciar o depósito.")
        this.setDepositLoading(false)
        return
      }

      window.location.href = data.checkout_url
    } catch (e) {
      console.error("[Wallet] deposit falhou:", e)
      this.showDepositError("Falha de conexão. Verifique sua internet e tente novamente.")
      this.setDepositLoading(false)
    }
  }

  setDepositLoading(isLoading) {
    if (!this.hasDepositButtonTarget) return
    this.depositButtonTarget.classList.toggle("is-loading", isLoading)
    this.depositButtonTarget.disabled = isLoading
  }

  showDepositError(message) {
    if (!this.hasDepositErrorTarget) return
    this.depositErrorTarget.textContent = message
    this.depositErrorTarget.classList.add("is-visible")
  }

  hideDepositError() {
    if (!this.hasDepositErrorTarget) return
    this.depositErrorTarget.classList.remove("is-visible")
  }

  // ───────────────────────── Helpers ─────────────────────────
  async fetchJson(url) {
    const response = await fetch(url, { headers: { Accept: "application/json" } })
    if (!response.ok) throw new Error(`GET ${url} -> ${response.status}`)
    return response.json()
  }

  setLoading(isLoading) {
    if (!this.hasWithdrawButtonTarget) return
    this.withdrawButtonTarget.classList.toggle("is-loading", isLoading)
    this.withdrawButtonTarget.disabled = isLoading
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.add("is-visible")
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.classList.remove("is-visible")
  }

  formatNumber(cents) {
    return (cents / 100).toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

  formatCents(cents) {
    return (cents / 100).toLocaleString("pt-BR", { style: "currency", currency: "BRL" })
  }

  // Aceita "R$ 120,00", "120,00", "120.00" ou "120"
  parseAmountToCents(rawValue) {
    const cleaned = (rawValue || "").replace(/[^\d,.-]/g, "")
    const normalized = cleaned.includes(",")
      ? cleaned.replace(/\./g, "").replace(",", ".")
      : cleaned
    const amount = parseFloat(normalized)
    return Number.isNaN(amount) ? 0 : Math.round(amount * 100)
  }

  formatDate(iso) {
    const date = new Date(iso)
    if (Number.isNaN(date.getTime())) return ""
    const day = date.toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit" })
    const time = date.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
    return `${day}, ${time}`
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str || ""
    return div.innerHTML
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
