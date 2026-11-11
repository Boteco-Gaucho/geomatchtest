class ReportsController < ApplicationController
  before_action :authenticate_user!

  def create
    @report = Report.new(report_params)
    @report.reporter = current_user
    if @report.save
      respond_to do |format|
        format.json { head :created }
        format.html { redirect_to safety_center_path, notice: "Denúncia enviada com sucesso!" }
      end
    else
      respond_to do |format|
        format.json { render json: { error: @report.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, alert: "Erro ao enviar denúncia." }
      end
    end
  end

  private

  def report_params
    # Permite a descrição e o array de fotos
    params.require(:report).permit(:description, photos: [])
  end
end