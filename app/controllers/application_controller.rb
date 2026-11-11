class ApplicationController < ActionController::Base
  helper :seo

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :disable_cache_for_auth, if: :devise_controller?
  before_action :update_last_seen, if: :user_signed_in?
  before_action :require_onboarding!, if: :user_signed_in?
  before_action :set_default_seo_tags

  rescue_from ActionController::InvalidAuthenticityToken, with: :redirect_and_refresh_token

  protected

  def configure_permitted_parameters
    # Adicionei :terms_of_use e :data_policy na lista de atributos permitidos
    attributes = [
      :username, :bio, :birthdate, :avatar, :gender, :phone, :address,
      :terms_of_use, :data_policy,
      :education_level, :zip_code, :street, :neighborhood, :city, :state
    ]

    devise_parameter_sanitizer.permit(:sign_up, keys: attributes)
    devise_parameter_sanitizer.permit(:account_update, keys: attributes + [:share_location])
  end

  # Atualiza o "visto por último" do usuário logado
  def update_last_seen
    # update_column -> rápido, sem validações, sem callbacks
    current_user.update_column(:last_seen_at, Time.current)
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Após login: retorna à página original se foi salva (ex: deep link de notificação iOS).
  # Fallback para /discover_3d nos acessos diretos ao /sign_in.
  def after_sign_in_path_for(resource)
    resource.touch(:last_location_updated_at)
    stored_location_for(resource) || discover_3d_path
  end

  private

  def require_onboarding!
    # Não bloquear requests JSON/API (ex: stories, notificações, localização)
    return if request.format.json?
    return if request.path.start_with?('/api/')
    return if devise_controller?
    return if controller_name == 'users' && action_name.in?(%w[onboarding complete_onboarding])
    return if controller_name == 'pages'

    # Rescue: se a coluna ainda não existe no banco (migração pendente), não travar
    completed = current_user.onboarding_completed?
    return if completed
    redirect_to onboarding_path
  rescue => e
    Rails.logger.warn "[require_onboarding!] #{e.class}: #{e.message}"
  end

  def disable_cache_for_auth
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"]        = "no-cache"
    response.headers["Expires"]       = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  def redirect_and_refresh_token
    redirect_to new_user_session_path, alert: "Sessão atualizada por segurança. Por favor, tente novamente."
  end

  def set_default_seo_tags
    image_url = view_context.image_url("logo-geomatch.svg")
    @seo_tags = {
      title: "GeoMatch — Conecte-se com pessoas reais perto de você",
      description: "Veja quem está a até 300 metros de você em tempo real. Chat instantâneo, mapa interativo, segurança em primeiro lugar.",
      image: image_url,
      url: request.url,
      og_title: "GeoMatch",
      og_description: "Conecte-se com pessoas reais a 300 metros de você.",
      og_image: image_url,
      og_type: "website",
      tw_card: "summary_large_image",
      tw_title: "GeoMatch",
      tw_description: "Conecte-se com pessoas reais perto de você.",
      tw_image: image_url
    }
  end
end