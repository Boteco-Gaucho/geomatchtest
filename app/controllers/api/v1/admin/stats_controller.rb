module Api
  module V1
    module Admin
      # GET /api/v1/admin/stats
      class StatsController < BaseController
        def show
          free_plan_id = Plan.find_by(name: 'Free')&.id

          paying_users = free_plan_id \
            ? User.where.not(plan_id: [nil, free_plan_id])
            : User.where.not(plan_id: nil)

          mrr_cents = paying_users
            .joins(:plan)
            .sum('plans.price_cents')

          @stats = {
            total_users:         User.count,
            active_now:          User.where('last_seen_at > ?', 5.minutes.ago).count,
            new_today:           User.where('created_at > ?', Time.current.beginning_of_day).count,
            total_matches:       Match.count,
            messages_today:      Message.where('created_at > ?', Time.current.beginning_of_day).count,
            pending_reports:     Report.pending.count,
            banned_users:        User.where.not(banned_at: nil).count,
            subscriptions_count: paying_users.count,
            mrr_cents:           mrr_cents.to_i
          }
        end
      end
    end
  end
end
