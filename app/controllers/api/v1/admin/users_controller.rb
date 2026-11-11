module Api
  module V1
    module Admin
      # GET   /api/v1/admin/users          → lista paginada
      # PATCH /api/v1/admin/users/:id/ban  → bane ou desbane a conta
      class UsersController < BaseController
        PAGE_SIZE = 30

        def index
          @users = User
            .includes(:plan, :latest_approved_payment)
            .order(created_at: :desc)
            .page(params[:page])
            .per(PAGE_SIZE)

          # Filtros textuais
          @users = @users.where('email ILIKE ?', "%#{params[:q]}%")    if params[:q].present?
          @users = @users.where.not(banned_at: nil)                    if params[:banned] == 'true'
          @users = @users.where(admin: true)                           if params[:admins] == 'true'

          # Filtro por plano
          @users = @users.where(plan_id: params[:plan_id])             if params[:plan_id].present?

          # Filtros de localização (colunas dedicadas, case-insensitive)
          @users = @users.where('city ILIKE ?',    "%#{params[:city]}%")    if params[:city].present?
          @users = @users.where('state ILIKE ?',   "%#{params[:state]}%")   if params[:state].present?
          @users = @users.where('country ILIKE ?', "%#{params[:country]}%") if params[:country].present?

          # Filtro demográfico
          @users = @users.where(gender: params[:gender])               if params[:gender].present?
          @users = apply_age_range(@users, params[:age_range])         if params[:age_range].present?

          # Filtro por escolaridade (enum integer → string key)
          if params[:education_level].present?
            level = User.education_levels[params[:education_level]]
            @users = @users.where(education_level: level) if level
          end
        end

        # PATCH /api/v1/admin/users/:id/update_subscription
        def update_subscription
          @user         = User.find(params[:id])
          plan          = Plan.find(params[:plan_id])
          old_plan_name = @user.plan&.name  # captura ANTES da transação

          ActiveRecord::Base.transaction do
            payment = Payment.create!(
              user:         @user,
              plan:         plan,
              payment_type: :admin_grant
            )
            payment.approve!

            AdminLog.create!(
              admin_id:    current_api_user.id,
              action:      'plan_change',
              target_id:   @user.id,
              target_type: 'User',
              details: {
                from_plan:  old_plan_name,
                to_plan:    plan.name,
                granted_by: current_api_user.email
              }
            )
          end

          render json: {
            id:                  @user.id,
            plan_id:             plan.id,
            plan_name:           plan.name,
            plan_is_admin_grant: true,
            message:             'Plano atualizado como cortesia (admin_grant).'
          }
        rescue ActiveRecord::RecordNotFound => e
          api_not_found(e.message)
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue AASM::InvalidTransition => e
          render json: { error: "Transição de estado inválida: #{e.message}" }, status: :unprocessable_entity
        end

        # PATCH /api/v1/admin/users/:id/ban
        def ban
          @user = User.find(params[:id])

          # Impede banir outro admin acidentalmente
          if @user.admin?
            return render json: { error: 'Não é possível banir um administrador.' }, status: :unprocessable_entity
          end

          if @user.banned?
            @user.unban!
            render json: { id: @user.id, banned: false, banned_at: nil, message: 'Conta reativada.' }
          else
            @user.ban!
            render json: { id: @user.id, banned: true, banned_at: @user.banned_at.iso8601, message: 'Conta suspensa.' }
          end
        rescue ActiveRecord::RecordNotFound
          api_not_found('Usuário não encontrado.')
        end

        private

        # age_range: "18-25", "26-35", "36-45", "46+"
        def apply_age_range(scope, range)
          case range
          when '18-25' then scope.filter_by_age(18, 25)
          when '26-35' then scope.filter_by_age(26, 35)
          when '36-45' then scope.filter_by_age(36, 45)
          when '46+'   then scope.filter_by_age(46, 120)
          else scope
          end
        end
      end
    end
  end
end
