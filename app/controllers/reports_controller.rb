class ReportsController < ApplicationController
  before_action :authenticate_user!

  # GET /report_incident(?user_id=…) — "Fazer uma denúncia". O chat, o perfil, o
  # swipe e o mapa mandam user_id: o perfil já chega escolhido em "Sobre quem?"
  def new
    @report = current_user.reports_sent.new(category: nil) # sem chip marcado (o banco usa "other" por padrão)
    if Report.reported_user_column? && params[:user_id].present?
      @report.reported_user = User.where.not(id: current_user.id).find_by(id: params[:user_id])
    end
    load_contacts
  end

  def create
    @report = current_user.reports_sent.new(report_params)

    if @report.save
      respond_to do |format|
        format.json { head :created }
        format.html { redirect_to safety_center_path, notice: "Denúncia enviada. Nossa equipe vai analisar com atenção." }
      end
    else
      respond_to do |format|
        format.json { render json: { error: @report.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          load_contacts
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def report_params
    permitted = [ :category, :description, photos: [] ]
    permitted.unshift(:reported_user_id) if Report.reported_user_column?
    attrs = params.require(:report).permit(*permitted)
    # file_field multiple manda um "" junto dos arquivos
    attrs[:photos] = Array(attrs[:photos]).compact_blank if attrs.key?(:photos)
    attrs
  end

  # "Sobre quem?": pessoas das conversas, mais quem veio escolhido (perfil, mapa…)
  def load_contacts
    return @contacts = [] unless Report.reported_user_column?

    avatar_includes = { avatar_attachment: :blob, album_photos_attachments: :blob }
    @contacts = current_user.matches
                            .includes(user: avatar_includes, matched_user: avatar_includes)
                            .order(created_at: :desc)
                            .filter_map { |match| match.other_user(current_user) }
                            .uniq
    chosen = @report.reported_user
    @contacts.unshift(chosen) if chosen && @contacts.exclude?(chosen)
  end
end
