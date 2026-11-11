module Api
  module V1
    module Admin
      # GET  /api/v1/admin/reports
      # PATCH /api/v1/admin/reports/:id/resolve
      class ReportsController < BaseController
        ITEMS_PER_PAGE = 20

        def index
          base = Report.includes(:reporter).order(created_at: :desc)
          base = base.by_category(params[:category]) if params[:category].present?

          case params[:status]
          when 'pending'  then base = base.pending
          when 'resolved' then base = base.resolved
          end

          page        = [params[:page].to_i, 1].max
          total       = base.count
          @reports    = base.offset((page - 1) * ITEMS_PER_PAGE).limit(ITEMS_PER_PAGE)

          @pagination = {
            current_page: page,
            total_pages:  [(total / ITEMS_PER_PAGE.to_f).ceil, 1].max,
            total_count:  total
          }

          @stats = {
            pending:  Report.pending.count,
            resolved: Report.resolved.count,
            banned:   User.where.not(banned_at: nil).count
          }

          @by_category = Report::CATEGORIES.index_with { |cat| Report.where(category: cat).count }
        rescue => e
          render json: {
            error:     e.class.to_s,
            message:   e.message,
            backtrace: e.backtrace&.first(5)
          }, status: :internal_server_error
        end

        def resolve
          report = Report.find(params[:id])
          if report.resolved?
            report.update!(resolved_at: nil)   # toggle: unresolve
            render json: { id: report.id, resolved: false, resolved_at: nil }
          else
            report.resolve!
            render json: { id: report.id, resolved: true, resolved_at: report.resolved_at }
          end
        end
      end
    end
  end
end
