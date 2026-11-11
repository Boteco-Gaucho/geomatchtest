module Api
  module V1
    module Admin
      # GET /api/v1/admin/performance
      class PerformanceController < BaseController
        def show
          @db_latency = measure_db_latency
          @pool_stat  = pool_info
          @revenue    = revenue_data
          @cache_stat = cache_info
        end

        private

        def measure_db_latency
          t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          ActiveRecord::Base.connection.execute("SELECT 1")
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000).round(2)
        rescue => e
          Rails.logger.error "DB latency check failed: #{e.message}"
          nil
        end

        def pool_info
          stat = ActiveRecord::Base.connection_pool.stat
          { size: stat[:size], busy: stat[:busy], idle: stat[:idle], waiting: stat[:waiting] }
        rescue
          { size: nil, busy: nil, idle: nil, waiting: nil }
        end

        def revenue_data
          paid          = Payment.where.not(paid_at: nil)
          total_cents   = paid.joins(:plan).sum('plans.price_cents').to_i
          total_users   = User.count
          premium_users = User.where('premium_until > ?', Time.current).count
          free_users    = total_users - premium_users

          {
            total_brl:       (total_cents / 100.0).round(2),
            paid_payments:   paid.count,
            premium_users:   premium_users,
            free_users:      free_users,
            total_users:     total_users,
            conversion_rate: total_users > 0 ? (premium_users.to_f / total_users * 100).round(1) : 0.0,
            # MRR aproximado: usuários premium ativos × ticket médio
            mrr_brl:         approx_mrr
          }
        end

        def approx_mrr
          avg_ticket_cents = Plan.where.not(price_cents: 0).average(:price_cents).to_f
          active_premium   = User.where('premium_until > ?', Time.current).count
          ((avg_ticket_cents * active_premium) / 100.0).round(2)
        rescue
          0.0
        end

        def cache_info
          { adapter: Rails.cache.class.name.demodulize }
        rescue
          { adapter: 'unknown' }
        end
      end
    end
  end
end
