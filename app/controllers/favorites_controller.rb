class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def index
    @favorites        = current_user.favorites.includes(:favorited_user).order(created_at: :desc)
    @favorited_users  = @favorites.map(&:favorited_user)
    @favorites_map    = @favorites.each_with_object({}) { |f, h| h[f.favorited_user_id] = f.id }
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
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: favorites_path }
    end
  end
end
