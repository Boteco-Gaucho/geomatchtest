class PathConfigurationsController < ApplicationController
  skip_before_action :require_onboarding!

  def show
    expires_in 1.hour, public: true
    render json: path_configuration
  end

  private

  def path_configuration
    {
      settings: {
        screenshots: "enabled"
      },
      rules: [
        # Regra padrão (catch-all): push normal para qualquer rota não mapeada
        {
          patterns: [".*"],
          properties: { context: "default", presentation: "default" }
        },
        # Autenticação: substitui a pilha de navegação (sem back button)
        {
          patterns: [
            "/users/sign_in",
            "/users/sign_up",
            "/users/password"
          ],
          properties: { context: "default", presentation: "replace" }
        },
        # Onboarding: também substitui a pilha
        {
          patterns: ["/onboarding"],
          properties: { context: "default", presentation: "replace" }
        },
        # Mapa 3D: replace para evitar empilhamento, cache e keep_alive para preservar
        # o estado do mapa (pins, subscrição ActionCable) ao navegar entre telas.
        # pull_to_refresh desabilitado pois o mapa tem seu próprio mecanismo de refresh.
        {
          patterns: ["/discover_3d"],
          properties: {
            context:               "default",
            presentation:          "replace",
            pull_to_refresh_enabled: false,
            cache_enabled:         true,
            keep_alive:            true
          }
        },
        # Rotas de segurança: push padrão sobre a pilha atual
        {
          patterns: [
            "/safety_center$",
            "/safety_center/history",
            "/report_incident"
          ],
          properties: { context: "default", presentation: "default" }
        },
        # Planos, checkout e verificação: abre como modal sheet
        {
          patterns: [
            "/plans",
            "/checkout",
            "/verificacao"
          ],
          properties: { context: "modal", presentation: "modal" }
        }
      ]
    }
  end
end
