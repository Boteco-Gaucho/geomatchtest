class UsersController < ApplicationController
  before_action :authenticate_user!

  # update_location aceita dois caminhos de autenticação:
  #   1. Bearer JWT  — app nativo iOS em background (sem WKWebView ativo, sem CSRF)
  #   2. Sessão web  — navegador / PWA (Devise session + CSRF normal)
  skip_before_action :verify_authenticity_token, only: [:update_location]
  skip_before_action :authenticate_user!,        only: [:update_location]
  before_action      :authenticate_for_location!, only: [:update_location]
  
  # ==========================================
  #  AÇÕES DE SEGURANÇA E INTERAÇÃO
  # ==========================================

  # Ação para bloquear usuário (Via POST)
  def block
    @user_to_block = User.find(params[:id])

    current_user.blocks_sent.create!(blocked: @user_to_block)

    Match.where(user: current_user, matched_user: @user_to_block)
         .or(Match.where(user: @user_to_block, matched_user: current_user))
         .destroy_all

    Like.where(liker: current_user, liked: @user_to_block).destroy_all
    Like.where(liker: @user_to_block, liked: current_user).destroy_all

    respond_to do |format|
      format.html { redirect_to lead_path, notice: "Usuário bloqueado." }
      format.json { head :ok }
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { redirect_to lead_path, alert: "Erro ao bloquear usuário." }
      format.json { head :unprocessable_entity }
    end
  end

  # Ação para desbloquear usuário (Via DELETE /users/:id/unblock)
  def unblock
    @user_to_unblock = User.find(params[:id])
    current_user.blocks_sent.find_by(blocked: @user_to_unblock)&.destroy
    redirect_to safety_history_path, notice: "#{@user_to_unblock.display_name} foi desbloqueado."
  end

  # Histórico: bloqueados + denúncias enviadas
  def safety_history
    @blocked_users = current_user.blocked_users.includes(:avatar_attachment, album_photos_attachments: :blob)
    @my_reports    = current_user.reports_sent.order(created_at: :desc)
    respond_to do |format|
      format.html
    end
  end

 # Ação para o botão de "Modo Invisível" no Mapa
  def toggle_visibility
    # 1. VERIFICAÇÃO: Só Gold pode usar
    unless current_user.can_use_invisible_mode?
      # Retorna um erro 403 (Proibido) com uma flag para o JS abrir o modal
      return render json: { upgrade_required: true, plan: 'Gold' }, status: :forbidden
    end

    # 2. Executa a troca se for Gold
    new_status = !current_user.invisible
    
    if current_user.update(invisible: new_status)
      render json: { invisible: new_status, message: "Visibilidade alterada" }, status: :ok
    else
      render json: { error: "Erro ao atualizar" }, status: :unprocessable_entity
    end
  end

  def update_location
    user = @location_user
    return head :ok if user.invisible

    lat = params[:latitude].to_f
    lng = params[:longitude].to_f

    return head :unprocessable_entity if lat.zero? && lng.zero?

    # update_columns ignora callbacks (geocoder, validações) — fundamental para
    # que este endpoint de heartbeat responda rapidamente sem efeitos colaterais.
    user.update_columns(
      latitude: lat,
      longitude: lng,
      last_seen_at: Time.zone.now,
      last_location_updated_at: Time.zone.now
    )
    broadcast_map_presence(user, lat, lng)
    head :ok
  end

  # ==========================================
  #  VIEWS PRINCIPAIS
  # ==========================================

  
  
  def discover_3d
  # Esta ação renderizará a view app/views/users/discover-3d.html.erb
  end


  def show
    @user = User.with_attached_avatar.with_attached_album_photos.find(params[:id])

    # SEGURANÇA: Verifica bloqueios antes de mostrar o perfil
    if current_user.excluded_user_ids.include?(@user.id)
      redirect_to discover_3d_path, alert: "Perfil indisponível."
      return
    end

    # MODO INVISÍVEL (navegação 100% oculta): perfil de usuário invisível fica
    # inacessível para todos — some da galeria, do mapa e também da tela de perfil.
    # O próprio usuário continua vendo o seu perfil normalmente.
    if @user.invisible? && @user.id != current_user.id
      redirect_to discover_3d_path, alert: "Perfil indisponível."
      return
    end

  rescue ActiveRecord::RecordNotFound
    redirect_to discover_3d_path, alert: "Usuário não encontrado."
  end

  def me_profile
    @user = current_user
    @user.album_photos.load
  end

  def safety_center
    respond_to do |format|
      format.html
    end
  end

  # Página de Denúncia
  def report_incident
    @reported_user = User.find_by(id: params[:user_id]) if params[:user_id].present?
    respond_to do |format|
      format.html
    end
  end

  def preview
    @user = current_user
  end

  # ==========================================
  #  ACTION LEAD (SWIPE / TINDER)
  # ==========================================
  def lead
    # 0. GARANTE LOCALIZAÇÃO (fallback DEV)
    if current_user.latitude.nil? || current_user.longitude.nil?
      current_user.update(latitude: -14.7876, longitude: -39.2781)
    end

    # 1. POPUP DE MATCH (Se acabou de dar match)
    if params[:match] == "true" && params[:match_id].present?
      @match = Match.find(params[:match_id])

      if @match.user_id == current_user.id || @match.matched_user_id == current_user.id
        @next_user = @match.other_user(current_user)
        # return (Removido return para não quebrar o resto da página se houver match)
        # Idealmente, o modal aparece SOBRE a tela normal. 
      end
    end

    # 2. FILTROS
    filters = {
      distance: params[:distance].presence || 500,
      min_age:  params[:min_age].presence || 18,
      max_age:  params[:max_age].presence || 60
    }

    @filter_distance = filters[:distance]
    @filter_min_age  = filters[:min_age]
    @filter_max_age  = filters[:max_age]

    # 3. BUSCA
    # Ignora: Já curtidos + Bloqueados + Quem me bloqueou
    # pluck(:liked_id) pega tanto likes quanto rejects (ambos estão na tabela likes)
    ignored_ids = current_user.likes.pluck(:liked_id) + current_user.excluded_user_ids
    
    @next_user, @distance = AdvancedDiscoveryService.new(current_user)
                                      .find_next_eligible_user(ignored_ids, filters)
  end

  # ==========================================
  #  API DO MAPA (NEARBY) -- CORRIGIDA --
  # ==========================================
  def nearby
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f

    # Verifica coordenadas ANTES de qualquer gravação.
    # Se o GPS enviar (0,0) (bug ou aquecimento pós-desbloqueio), não corrompemos
    # as coordenadas do utilizador na BD e não o fazemos desaparecer do mapa de outros.
    if latitude.zero? && longitude.zero?
      render json: [], status: :ok
      return
    end

    # Mínimo de 150m independente do slider: GPS de celular tem erro de 20-80m por
    # dispositivo — sem esse piso, raios curtos excluem usuários fisicamente próximos.
    raw_range_km = params[:range].present? ? (params[:range].to_f / 1000.0) : 0.3
    range_km = [raw_range_km, 0.15].max
    gender_filter = params[:gender]&.downcase

    if current_user && !current_user.invisible
      current_user.update_columns(
        latitude: latitude,
        longitude: longitude,
        last_seen_at: Time.current,
        last_location_updated_at: Time.current
      )
      broadcast_map_presence(current_user, latitude, longitude)
    end

    # Busca usuários próximos usando o Service
    users_data = DiscoveryService.new(current_user).find_nearby_users(range_km, gender_filter)

    # FILTRAGEM FINAL SEGURA:
    blocked_ids = current_user.excluded_user_ids
    
    visible_users = users_data.select do |u| 
      uid = u.respond_to?(:id) ? u.id : u[:id] || u['id']
      
      is_invisible = if u.respond_to?(:invisible)
                       u.invisible
                     elsif u.is_a?(Hash)
                       u[:invisible] || u['invisible'] || false
                     else
                       false
                     end

      !blocked_ids.include?(uid) && !is_invisible
    end

    # MAPEAMENTO DO JSON: Inserindo a lógica de Online/Offline
    final_json = visible_users.map do |u|
      # Lógica para determinar se o usuário está online (ativo nos últimos 5 minutos)
      # Funciona se for objeto User ou se o Service retornar last_seen_at no Hash
      last_activity = u.respond_to?(:last_seen_at) ? u.last_seen_at : (u[:last_seen_at] || u['last_seen_at'])
      is_online = last_activity.present? && last_activity > 10.minutes.ago

      if u.is_a?(Hash)
        u.merge({ online: is_online }) # Preserva verified (já vem do DiscoveryService) + injeta online
      else
        u.as_json(only: [:id, :username, :latitude, :longitude, :distance_km, :city, :bio, :gender, :interested_in, :hobbies_list]).merge({
          verified: u.verified?,
          avatar_url: u.avatar.attached? ? rails_blob_path(u.avatar, only_path: true) : nil,
          photos_urls: build_user_photos_urls(u),
          age: u.birthdate.present? ? ((Date.today - u.birthdate.to_date) / 365.25).floor : nil,
          online: is_online
        })
      end
    end

    render json: final_json
  rescue => e
    Rails.logger.error "Erro em /users/nearby: #{e.message}"
    render json: { error: "Erro interno", details: e.message }, status: :internal_server_error
  end

  # ==========================================
  #  EDIÇÃO DE PERFIL
  # ==========================================
  def edit
    @user = current_user
  end

  def update
  @user = current_user

  # 1. Tratamento das fotos do álbum
  if params[:user][:album_photos].present?
    @user.album_photos.attach(params[:user][:album_photos])
  end

  # 2. Removemos album_photos dos parâmetros de atualização em massa
  # para evitar que o Rails tente sobrescrever o que acabamos de anexar
  user_update_params = user_params.except(:album_photos)

  if @user.update(user_update_params)
    redirect_to edit_profile_path, notice: "Perfil atualizado!", status: :see_other
  else
    render :edit, status: :unprocessable_entity
  end
end

  def upload_avatar
    @user = current_user
    file  = params.dig(:user, :avatar_original) || params[:avatar_original]

    unless file.present?
      redirect_to edit_profile_path, alert: "Nenhuma imagem foi recebida. Tente novamente.", status: :see_other
      return
    end

    @user.avatar_original.attach(file)
    redirect_to crop_avatar_profile_path, status: :see_other
  end

  def crop_avatar
    @user = current_user
    unless @user.avatar_original.attached?
      redirect_to edit_profile_path
    end
  end

  def apply_crop
    @user = current_user
    file  = params[:avatar]
    unless file
      render json: { error: "arquivo ausente" }, status: :unprocessable_entity
      return
    end
    @user.avatar.attach(file)
    render json: { ok: true }
  end

  def reject
    target_user = User.find_by(id: params[:user_id])

    # Detecta "lost match": o alvo já curtiu o current_user antes de levarmos um nope
    lost_match = target_user &&
                 Like.where(liker_id: target_user.id, liked_id: current_user.id)
                     .where.not(is_like: false)
                     .exists?

    current_user.likes.create(liked_id: params[:user_id], is_like: false)

    if params[:source] == "map"
      return head :ok
    end

    respond_to do |format|
      format.turbo_stream do
        ignored_ids  = current_user.likes.pluck(:liked_id) + current_user.excluded_user_ids
        @next_user, @distance = AdvancedDiscoveryService.new(current_user)
                                  .find_next_eligible_user(
                                    ignored_ids,
                                    { distance: 500, min_age: 18, max_age: 60 }
                                  )

        streams = []
        if lost_match
          streams << turbo_stream.prepend("toast-container",
            partial: "shared/toast",
            locals: { message: "Você acabou de perder um match! 💔", type: "alert" })
        end
        streams << turbo_stream.update("swipe-area",
          partial: "users/swipe_area",
          locals: { next_user: @next_user, distance: @distance })

        render turbo_stream: streams
      end
      format.html do
        flash[:alert] = "Você acabou de perder um match! 💔" if lost_match
        redirect_to lead_path
      end
    end

  rescue ActiveRecord::RecordNotFound
    if params[:source] == "map"
      head :not_found
    else
      redirect_to lead_path
    end
  end

  def rewind
    last_reject = current_user.likes
                               .where(is_like: false)
                               .order(created_at: :desc)
                               .first

    unless last_reject
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("rewind-flash",
            "<span class='rewind-empty-msg'>Nenhum perfil para voltar</span>")
        }
        format.html { redirect_to lead_path, alert: "Nenhum perfil para voltar." }
      end
      return
    end

    @next_user = User.find_by(id: last_reject.liked_id)
    last_reject.destroy

    @distance = if @next_user && current_user.latitude && current_user.longitude &&
                   @next_user.latitude && @next_user.longitude
      Geocoder::Calculations.distance_between(
        [current_user.latitude, current_user.longitude],
        [@next_user.latitude, @next_user.longitude],
        units: :km
      ).round(1)
    end

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.update("swipe-area",
          partial: "users/swipe_area",
          locals: { next_user: @next_user, distance: @distance })
      }
      format.html { redirect_to lead_path }
    end
  end

  # Exibe a tela de solicitação
  def onboarding
    redirect_to lead_path if current_user.onboarding_completed?
    @hide_sidebar = true
  end

  def complete_onboarding
    @hide_sidebar = true
    permitted = params.require(:user).permit(:gender, :interested_in, :education_level, :birthdate, :phone, :zip_code, :street, :neighborhood, :city, :state)

    @errors = []
    @errors << "Selecione seu gênero"                    if permitted[:gender].blank?
    @errors << "Selecione quem você quer conhecer"       if permitted[:interested_in].blank?
    @errors << "Selecione sua escolaridade"              if permitted[:education_level].blank?
    @errors << "Data de nascimento é obrigatória"        if permitted[:birthdate].blank?
    @errors << "Telefone é obrigatório"                  if permitted[:phone].blank?
    @errors << "Informe o CEP para localizarmos você"    if permitted[:zip_code].blank?

    if @errors.any?
      render :onboarding, status: :unprocessable_entity
      return
    end

    current_user.assign_attributes(permitted)

    if current_user.save
      # update_column vai direto no banco, sem validações/callbacks
      # garante que onboarding_completed persiste mesmo que geocoder ou outra
      # callback interfira no save principal
      current_user.update_column(:onboarding_completed, true)

      # Aplica cupom, se fornecido (campo opcional do onboarding).
      # Falha no cupom não bloqueia o onboarding — apenas avisa via flash[:alert].
      flash[:notice] = "Perfil completado! Bem-vindo ao GeoMatch 🎉"
      if params[:user][:coupon_code].present?
        coupon_result = current_user.apply_coupon(params[:user][:coupon_code])
        if coupon_result[:success]
          flash[:notice] = "Perfil completado! #{coupon_result[:message]}"
        else
          flash[:alert] = coupon_result[:message]
        end
      end

      redirect_to lead_path
    else
      @errors = current_user.errors.full_messages
      render :onboarding, status: :unprocessable_entity
    end
  end

  def verification
    # Se o usuário já enviou uma foto antes, podemos mostrar um aviso ou status
  end

  # Processa o envio dos documentos KYC (frente, verso e selfie)
  def send_verification
    front  = params[:document_front]
    back   = params[:document_back]
    selfie = params[:selfie_with_document]

    unless front.present? && back.present? && selfie.present?
      Rails.logger.error "[send_verification] Documentos incompletos para User##{current_user.id}. Recebidos: #{params.to_unsafe_h.keys}"
      flash[:alert] = "Por favor, envie as três fotos obrigatórias para continuar."
      render :verification and return
    end

    begin
      Rails.logger.info "[send_verification] Anexando documentos KYC para User##{current_user.id}"
      current_user.document_front.attach(front)
      current_user.document_back.attach(back)
      current_user.selfie_with_document.attach(selfie)
      current_user.update_columns(
        ai_moderation_status:  "pending",
        ai_moderation_score:   nil,
        ai_moderation_details: nil
      )
      AnalyzeVerificationPhotoJob.perform_later(current_user.id)
      flash[:notice] = "Documentos enviados com sucesso! Nossa equipe irá analisar seu KYC em breve."
      redirect_to my_profile_path
    rescue => e
      Rails.logger.error "[send_verification] Erro ao anexar documentos para User##{current_user.id}: #{e.message}"
      flash[:alert] = "Erro ao salvar os documentos. Tente novamente."
      render :verification
    end
  end

  # Aplica um cupom a partir da tela de perfil (/meu-perfil)
  def apply_coupon
    coupon_code = params[:coupon_code].to_s.strip

    if coupon_code.present?
      coupon_result = current_user.apply_coupon(coupon_code)
      if coupon_result[:success]
        flash[:notice] = coupon_result[:message]
      else
        flash[:alert] = coupon_result[:message]
      end
    else
      flash[:alert] = "Por favor, insira um código de cupom."
    end

    redirect_to my_profile_path
  end

  # ==========================================
  #  PRIVATE
  # ==========================================
  private

  # Autenticação dual para POST /users/update_location.
  #
  # Caminho JWT (app nativo iOS em background):
  #   Header  → Authorization: Bearer <token>
  #   Token   → JWT gerado por JwtService, exposto via <meta name="api-token">
  #   CSRF    → não verificado (não há cookie de sessão em requests nativos)
  #
  # Caminho web (navegador / PWA):
  #   Auth    → Devise session (current_user)
  #   CSRF    → verificado manualmente (presence.js inclui X-CSRF-Token ou
  #              authenticity_token no corpo para sendBeacon)
  def authenticate_for_location!
    auth_header = request.headers['Authorization']

    if auth_header&.start_with?('Bearer ')
      token          = auth_header.split(' ', 2).last
      payload        = JwtService.decode(token)
      @location_user = User.find(payload[:sub])
    else
      verify_authenticity_token
      unless user_signed_in?
        head :unauthorized
        return
      end
      @location_user = current_user
    end
  rescue JWT::ExpiredSignature
    render json: { error: 'Token expirado' }, status: :unauthorized
  rescue JWT::DecodeError
    render json: { error: 'Token inválido' }, status: :unauthorized
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Usuário não encontrado' }, status: :unauthorized
  rescue ActionController::InvalidAuthenticityToken
    head :unprocessable_entity
  end

  def build_user_photos_urls(user)
    urls = []
    urls << rails_blob_path(user.avatar, only_path: true) if user.has_real_avatar?
    user.album_photos.each { |p| urls << rails_blob_path(p, only_path: true) }
    urls
  rescue => e
    Rails.logger.error "build_user_photos_urls error for User##{user.id}: #{e.message}"
    []
  end

  def broadcast_map_presence(user, lat, lng)
    return if user.invisible

    ActionCable.server.broadcast("map_updates", {
      action:        "update",
      user_id:       user.id,
      username:      user.display_name.presence || user.username,
      lat:           lat,
      lng:           lng,
      avatar_url:    if user.has_real_avatar?
                       rails_blob_path(user.avatar, only_path: true)
                     elsif (first = user.album_photos.first)
                       rails_blob_path(first, only_path: true)
                     end,
      photos_urls:   build_user_photos_urls(user),
      verified:      user.verified?,
      bio:           user.bio,
      city:          user.city,
      gender:        user.gender,
      interested_in: user.interested_in,
      hobbies_list:  user.hobbies_list,
      birthdate:     user.birthdate,
      age:           user.birthdate.present? ? ((Date.today - user.birthdate.to_date) / 365.25).floor : nil
    })
  end

  def user_params
    params.require(:user).permit(
      :avatar, :username, :bio, :birthdate, :gender,
      :share_location, :interested_in, :invisible,
      :city, :state, :coupon_code,
      { hobbies_list: [] },
      album_photos: []
    )
  end

end