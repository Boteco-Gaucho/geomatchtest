# Conta congelada (User#freeze_account!) volta ao entrar de novo pelo site:
# login com senha ou cookie "lembrar de mim". Na próxima página aparece o aviso
# "Que bom que você ficou!" (shared/_unfreeze_toast.html.erb). O login do app
# (API JWT) descongela em Api::V1::AuthController#login.
Warden::Manager.after_authentication do |user, auth, _opts|
  next unless user.is_a?(User) && user.account_frozen?

  user.unfreeze_account!
  ActionDispatch::Request.new(auth.env).flash[:account_unfrozen] = true
end
