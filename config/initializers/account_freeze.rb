# Conta congelada (User#freeze_account!) volta ao entrar de novo pelo site:
# login com senha ou cookie "lembrar de mim". O login do app (API JWT) descongela
# em Api::V1::AuthController#login.
Warden::Manager.after_authentication do |user, _auth, _opts|
  user.unfreeze_account! if user.is_a?(User)
end
