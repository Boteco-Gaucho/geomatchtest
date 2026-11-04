class FavoritesController < ApplicationController
  before_action :authenticate_user!

  # Favoritos (/favorites) — quem a pessoa salvou na estrela. Some da lista quem
  # bloqueou/foi bloqueado e quem foi banido (o registro continua; volta se desbloquear).
  def index
    @favorites = visible_favorites
                   .includes(favorited_user: [ { avatar_attachment: :blob }, { album_photos_attachments: :blob } ])
                   .order(created_at: :desc)
                   .to_a
  end

  def create
    @favorite = current_user.favorites.find_or_create_by(favorited_user_id: params[:favorited_user_id])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: favorites_path }
    end
  end

  def destroy
    @favorite = current_user.favorites.includes(:favorited_user).find(params[:id])
    @favorite.destroy
    # Na própria tela de Favoritos o card sai da lista e a contagem é refeita
    @remaining = visible_favorites.count if params[:source] == "favorites"
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: favorites_path }
    end
  end

  private

  def visible_favorites
    current_user.favorites
                .joins(:favorited_user)
                .where(users: { banned_at: nil })
                .where.not(favorited_user_id: current_user.excluded_user_ids)
  end
end
