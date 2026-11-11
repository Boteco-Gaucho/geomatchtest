module Api
  module V1
    module Admin
      # GET /api/v1/admin/analytics?from=YYYY-MM-DD&to=YYYY-MM-DD
      class AnalyticsController < BaseController
        def show
          @from = parse_date(params[:from]) || 30.days.ago.to_date
          @to   = parse_date(params[:to])   || Date.current

          @growth       = daily_growth
          @retention    = retention_data
          @engagement   = engagement_data
          @demographics = demographics_data
          @bot_alerts   = detect_bots
        end

        private

        # ── Crescimento diário de novos usuários ──────────────────────
        def daily_growth
          User
            .where(created_at: @from.beginning_of_day..@to.end_of_day)
            .group(Arel.sql("DATE_TRUNC('day', created_at)::date"))
            .order(Arel.sql("DATE_TRUNC('day', created_at)::date"))
            .count
            .transform_keys(&:to_s)
        end

        # ── Retenção D1 / D7 / D30 ───────────────────────────────────
        def retention_data
          { d1: calc_retention(1), d7: calc_retention(7), d30: calc_retention(30) }
        end

        def calc_retention(days)
          # Coorte: usuários que se cadastraram há pelo menos `days` dias
          # e cujo período de observação já encerrou (janela de 90 dias)
          cohort_end   = days.days.ago
          cohort_start = (90 + days).days.ago

          base = User.where(created_at: cohort_start..cohort_end).count
          return { rate: 0.0, base: 0, returned: 0 } if base.zero?

          returned = User
            .where(created_at: cohort_start..cohort_end)
            .where("last_seen_at >= created_at + interval '#{days} days'")
            .count

          { rate: (returned.to_f / base * 100).round(1), base: base, returned: returned }
        end

        # ── Engajamento no período ────────────────────────────────────
        def engagement_data
          range = @from.beginning_of_day..@to.end_of_day
          matches  = Match.where(created_at: range).count
          messages = Message.where(created_at: range).count

          {
            matches:                matches,
            messages:               messages,
            avg_messages_per_match: matches > 0 ? (messages.to_f / matches).round(1) : 0.0
          }
        end

        # ── Demografia por plano ──────────────────────────────────────
        def demographics_data
          by_plan   = User.joins(:plan).group('plans.name').count
          by_gender = User.where.not(gender: [nil, '']).group(:gender).count

          { by_plan: by_plan, by_gender: by_gender }
        end

        # ── Detecção de Bot: >500 likes na última hora ────────────────
        def detect_bots
          suspicious = Like
            .where('created_at > ?', 1.hour.ago)
            .group(:liker_id)
            .having('COUNT(*) > 500')
            .count

          return [] if suspicious.empty?

          users = User.where(id: suspicious.keys).index_by(&:id)
          suspicious.map do |uid, count|
            u = users[uid]
            { user_id: uid, like_count_1h: count, email: u&.email, name: u&.display_name }
          end.sort_by { |a| -a[:like_count_1h] }
        end

        def parse_date(str)
          Date.parse(str)
        rescue
          nil
        end
      end
    end
  end
end
