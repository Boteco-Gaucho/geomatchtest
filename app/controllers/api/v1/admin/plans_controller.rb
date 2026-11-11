# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Controller para gestão de planos de assinatura (SaaS)
      # Herda autenticação JWT e verificação de admin de BaseController
      class PlansController < Api::V1::Admin::BaseController
        before_action :set_plan, only: [:show, :update, :destroy]

        # GET /api/v1/admin/plans
        # Lista todos os planos (ativos e inativos) para gestão completa
        def index
          ActiveRecord::Base.connection.schema_cache.clear!
          @plans = Plan.order(:price_cents, :name)

          render json: {
            plans: @plans.map { |plan| serialize_plan(plan) },
            meta: {
              total: @plans.count,
              active: @plans.where(active: true).count,
              inactive: @plans.where(active: false).count
            }
          }, status: :ok
        rescue => e
          Rails.logger.error "[PlansController#index] #{e.message}\n#{e.backtrace.first(5).join("\n")}"
          render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: :internal_server_error
        end

        # GET /api/v1/admin/plans/:id
        # Mostra detalhes de um plano específico
        def show
          render json: {
            plan: serialize_plan(@plan, detailed: true)
          }, status: :ok
        end

        # POST /api/v1/admin/plans
        # Cria um novo plano de assinatura
        def create
          @plan = Plan.new(plan_params)

          if @plan.save
            render json: {
              message: 'Plano criado com sucesso.',
              plan: serialize_plan(@plan)
            }, status: :created
          else
            render json: {
              error: 'Erro ao criar plano.',
              details: @plan.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue StandardError => e
          Rails.logger.error "[PlansController#create] #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          render json: { error: e.message }, status: :internal_server_error
        end

        # PATCH/PUT /api/v1/admin/plans/:id
        # Atualiza um plano existente
        def update
          if @plan.update(plan_params)
            render json: {
              message: 'Plano atualizado com sucesso.',
              plan: serialize_plan(@plan)
            }, status: :ok
          else
            render json: {
              error: 'Erro ao atualizar plano.',
              details: @plan.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/plans/:id
        # Soft delete: desativa o plano em vez de deletar
        # Isso preserva assinaturas antigas que referenciam este plano
        def destroy
          if @plan.update(active: false)
            render json: {
              message: 'Plano desativado com sucesso. Assinaturas existentes permanecem válidas.',
              plan: serialize_plan(@plan)
            }, status: :ok
          else
            render json: {
              error: 'Erro ao desativar plano.',
              details: @plan.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def set_plan
          @plan = Plan.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Plano não encontrado.' }, status: :not_found
        end

        # Parâmetros permitidos para criação/atualização de planos
        def plan_params
          params.fetch(:plan, params).permit(
            :code,
            :name,
            :description,
            :price_cents,
            :price_currency,
            :duration_days,
            :duration_months,
            :max_likes_per_day,
            :has_boost,
            :has_incognito,
            :active,
            :is_recommended,
            features: {}
          )
        end

        # Serializa um plano para JSON
        # @param detailed [Boolean] Se true, inclui campos extras
        def serialize_plan(plan, detailed: false)
          base = {
            id: plan.id,
            code: plan.code,
            name: plan.name,
            description: plan.description,
            price_cents: plan.price_cents,
            price_currency: plan.price_currency,
            price_formatted: format_price(plan.price_cents, plan.price_currency),
            duration_days: plan.duration_days,
            duration_months: plan.duration_months,
            max_likes_per_day: plan['max_likes_per_day'] || 50,
            has_boost: !!plan['has_boost'],
            has_incognito: !!plan['has_incognito'],
            active: plan.active == true,
            is_recommended: plan.is_recommended == true,
            features: plan.features,
            created_at: plan.created_at,
            updated_at: plan.updated_at
          }

          # Sempre incluir contagem de assinaturas ativas para o dashboard
          # Usuários com plan_id preenchido têm plano ativo
          base[:active_subscriptions] = plan.users.where.not(plan_id: nil).count
          
          if detailed
            base.merge!(
              payments_count: plan.payments.count
            )
          end

          base
        end

        # Formata o preço para exibição
        def format_price(cents, currency)
          return 'Grátis' if cents == 0
          
          Money.new(cents, currency).format
        rescue
          "#{cents / 100.0} #{currency}"
        end
      end
    end
  end
end
