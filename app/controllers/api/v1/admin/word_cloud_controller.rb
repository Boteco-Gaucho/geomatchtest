module Api
  module V1
    module Admin
      # GET /api/v1/admin/word_cloud
      # Params: from, to (YYYY-MM-DD), region (string)
      class WordCloudController < BaseController
        def index
          from   = parse_date(params[:from], default: 30.days.ago)
          to     = parse_date(params[:to],   default: Time.current).end_of_day
          region = params[:region]

          @result = MessageAnalyzer.analyze(from: from, to: to, region: region)
        end

        private

        def parse_date(val, default:)
          val.present? ? Date.parse(val) : default
        rescue Date::Error
          default
        end
      end
    end
  end
end
