module Api
  module V1
    module Admin
      # GET /api/v1/admin/logs
      class LogsController < BaseController
        PAGE_SIZE = 50

        def index
          logs = AdminLog
            .includes(:admin)
            .latest_first
            .page(params[:page])
            .per(PAGE_SIZE)

          logs = logs.by_action(params[:log_action])      if params[:log_action].present?
          logs = logs.by_admin(params[:admin_id])         if params[:admin_id].present?
          logs = logs.for_target('User', params[:user_id]) if params[:user_id].present?

          render json: {
            pagination: {
              current_page: logs.current_page,
              total_pages:  logs.total_pages,
              total_count:  logs.total_count
            },
            logs: logs.map { |log|
              {
                id:          log.id,
                action:      log.action,
                admin_id:    log.admin_id,
                admin_email: log.admin&.email,
                admin_name:  log.admin&.display_name,
                target_id:   log.target_id,
                target_type: log.target_type,
                details:     log.details,
                created_at:  log.created_at.iso8601
              }
            }
          }
        end
      end
    end
  end
end
