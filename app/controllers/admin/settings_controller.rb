class Admin::SettingsController < Admin::BaseController
  SETTING_META = {
    'one_off_message_price' => {
      label:       'Preço da Mensagem Avulsa',
      description: 'Valor cobrado por mensagem avulsa para usuários do plano Free.',
      type:        :price
    }
  }.freeze

  def index
    @settings = Setting.order(:key).map { |s| build_item(s) }
  end

  def edit
    @setting = Setting.find(params[:id])
    @meta    = SETTING_META[@setting.key] || { label: @setting.key.humanize, description: '', type: :integer }
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_settings_path, alert: "Configuração não encontrada."
  end

  def update
    @setting  = Setting.find(params[:id])
    meta      = SETTING_META[@setting.key] || { label: @setting.key.humanize, description: '', type: :integer }
    raw       = params.dig(:setting, :value).to_s.strip
    new_value = meta[:type] == :price ? parse_price_to_cents(raw) : raw.to_i

    if @setting.update(value: new_value)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Configuração atualizada com sucesso!"
          render turbo_stream: [
            turbo_stream.replace(
              "setting_#{@setting.id}",
              partial: "admin/settings/setting",
              locals:  { item: build_item(@setting) }
            ),
            turbo_stream.prepend("toast-container", partial: "shared/flash")
          ]
        end
        format.html { redirect_to admin_settings_path, notice: "Configuração atualizada com sucesso!" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Erro: #{@setting.errors.full_messages.join(', ')}"
          render turbo_stream: turbo_stream.prepend("toast-container", partial: "shared/flash"),
                 status: :unprocessable_entity
        end
        format.html { redirect_to admin_settings_path, alert: "Erro ao salvar." }
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_settings_path, alert: "Configuração não encontrada."
  end

  private

  def build_item(setting)
    meta = SETTING_META[setting.key] || { label: setting.key.humanize, description: '', type: :integer }
    { setting: setting, label: meta[:label], description: meta[:description], type: meta[:type] }
  end

  def parse_price_to_cents(raw)
    (raw.tr(',', '.').to_f * 100).round
  end
end
