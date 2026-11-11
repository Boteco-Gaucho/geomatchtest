# app/controllers/stories_controller.rb
class StoriesController < ApplicationController
  # Assumindo que você usa Devise ou outro sistema de autenticação
  before_action :authenticate_user!
  # Opcional: Desabilitar CSRF para API, mas o frontend envia o token
  # skip_before_action :verify_authenticity_token, only: [:create]

    # GET /stories
  # Retorna stories próximos ao usuário logado
  def index
    # 1. Obter a localização do usuário logado
    current_lat = current_user.latitude
    current_lng = current_user.longitude

    if current_lat.present? && current_lng.present?
      # 2. Buscar stories próximos (ex: 50 km)
      # Excluir stories muito antigos (ex: 24 horas)
      @stories = Story.nearby(current_lat, current_lng, 50)
                      .where('created_at >= ?', 24.hours.ago)
                      .includes(:user)
                      .distinct
                      .order(created_at: :desc)
    else
      @stories = []
    end

    # 3. Responder com JSON
    # CORREÇÃO: Usar .to_a para garantir que o as_json customizado do modelo seja chamado
    # em cada story, e não na coleção ActiveRecord::Relation.
    render json: @stories.to_a.as_json
  end

  # POST /stories
  # Cria um novo story
  def create
    # 1. Criar o story associado ao usuário logado
    @story = current_user.stories.new(story_params)

    # 2. Adicionar a localização atual do usuário ao story
    @story.latitude = current_user.latitude
    @story.longitude = current_user.longitude

    if @story.save
      # 3. Responder com sucesso
      render json: { message: 'Story publicado com sucesso!', story: @story.as_json }, status: :created
    else
      # 4. Responder com erro
      render json: { error: @story.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def story_params
    # Permitir o anexo de mídia (Active Storage) e a legenda
    params.require(:story).permit(:caption, :media)
  end
end