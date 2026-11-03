class Discover3dController < ApplicationController
  before_action :authenticate_user!

  GALLERY_LIMIT = 60

  # Mapeia o param :sexo para os valores reais do campo gender no banco.
  # "nao-binario" cobre variantes com/sem acento de registros antigos.
  GENDER_MAPPING = {
    "homem"       => ["homem"],
    "mulher"      => ["mulher"],
    "nao-binario" => ["não binário", "nao binario", "não-binário"]
  }.freeze

  def gallery
    base = User.visible
               .findable_in_city_search
               .where.not(id: current_user.excluded_user_ids + [current_user.id])

    @filters = {
      sexo:  params[:sexo].presence,
      state: params[:state].presence,
      city:  params[:city].presence
    }

    scope = base
    if @filters[:sexo]
      targets = GENDER_MAPPING[@filters[:sexo].downcase]
      scope = scope.where("LOWER(gender) IN (?)", targets) if targets
    end
    scope = scope.where("state ILIKE ?", @filters[:state].strip) if @filters[:state]
    scope = scope.where("city ILIKE ?", @filters[:city].strip)   if @filters[:city]

    if @filters.values.all?(&:blank?)
      # Sem filtros: perfis em destaque (verificados → premium → mais ativos)
      free_plan_id = Plan.find_by(name: "Free")&.id
      scope = scope.order(verified: :desc)
      scope = scope.order(Arel.sql("CASE WHEN plan_id = #{free_plan_id.to_i} THEN 1 ELSE 0 END")) if free_plan_id
      scope = scope.order(Arel.sql("last_seen_at DESC NULLS LAST"))
    else
      scope = scope.order(Arel.sql("last_seen_at DESC NULLS LAST"))
    end

    @users = scope.with_attached_avatar
                  .with_attached_album_photos
                  .limit(GALLERY_LIMIT)

    @favorites_map = current_user.favorites
                                  .where(favorited_user_id: @users.map(&:id))
                                  .each_with_object({}) { |f, h| h[f.favorited_user_id] = f.id }
  end

  # POST /discover_3d/gallery/visibility — olho da tela Explorar cidades (recurso Gold).
  # Some só desta busca: o mapa continua mostrando a pessoa (lá vale users.invisible).
  def toggle_city_search_visibility
    unless current_user.can_use_invisible_mode?
      return render json: { upgrade_required: true, plan: "Gold" }, status: :forbidden
    end
    unless User.city_search_hiding?
      return render json: { error: "Recurso indisponível no momento." }, status: :service_unavailable
    end

    hidden = !current_user.hidden_from_city_search?
    current_user.update_column(:hidden_from_city_search, hidden)
    render json: { hidden: hidden }
  end
end
