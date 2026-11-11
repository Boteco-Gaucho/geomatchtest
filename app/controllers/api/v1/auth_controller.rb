module Api
  module V1
    # POST /api/v1/login
    # Não requer autenticação prévia — herda direto de ActionController::Base.
    class AuthController < ActionController::Base
      skip_before_action :verify_authenticity_token

      def login
        user = User.find_by(email: params[:email].to_s.downcase.strip)

        unless user&.valid_password?(params[:password].to_s)
          return render json: { error: 'Email ou senha incorretos.' }, status: :unauthorized
        end

        if user.banned?
          return render json: { error: 'Conta suspensa. Entre em contato com o suporte.' }, status: :forbidden
        end

        token = JwtService.encode(sub: user.id)

        response.set_header('Authorization', "Bearer #{token}")

        render json: {
          token:      token,
          expires_in: 30.days.to_i,
          user: {
            id:         user.id,
            name:       user.display_name,
            email:      user.email,
            avatar_url: user.avatar_url,
            premium:    user.premium?,
            verified:   user.verified?,
            admin:      user.admin?
          }
        }, status: :ok
      end
    end
  end
end
