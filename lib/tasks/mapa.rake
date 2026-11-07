# Diagnóstico do mapa (/discover_3d): para uma conta, quem apareceria no mapa dela agora
# e, para cada pessoa que NÃO aparece, o motivo. Usa o mesmo DiscoveryService do mapa.
#
#   bin/rails "mapa:diagnostico[email@da.conta]"
#   bin/rails "mapa:diagnostico[email@da.conta,50]"   # lista até 50 pessoas (padrão 30)
#
# Regras do mapa: só quem atualizou a localização nos últimos 5 min, a até 300 m,
# fora do modo oculto, com a localização em tempo real ligada, não congelado, não
# banido e sem bloqueio entre as duas contas.
namespace :mapa do
  desc "Mostra quem aparece no mapa de uma conta e por que os outros não aparecem"
  task :diagnostico, [ :email, :limite ] => :environment do |_task, args|
    viewer = User.find_by(email: args[:email].to_s.downcase.strip)
    abort "Conta não encontrada: #{args[:email].inspect}" unless viewer

    limite = (args[:limite] || 30).to_i
    origem = [ viewer.latitude, viewer.longitude ]
    puts "Conta: #{viewer.email} (id #{viewer.id})"
    puts "  posição salva: #{origem.all?(&:present?) ? origem.join(', ') : 'NENHUMA (abra o mapa para enviar)'}"
    puts "  última atualização: #{viewer.last_location_updated_at || 'nunca'}"
    puts "  modo oculto: #{viewer.invisible? ? 'LIGADO' : 'desligado'} · localização em tempo real: #{viewer.sharing_location? ? 'ligada' : 'DESLIGADA'}" \
         " · congelada: #{viewer.account_frozen? ? 'SIM' : 'não'}"
    puts

    if origem.any?(&:blank?)
      puts "Sem posição salva não dá para calcular quem está perto. Abra o mapa com essa conta e rode de novo."
      next
    end

    aparecem = DiscoveryService.new(viewer).find_nearby_users(User::MAP_RADIUS_KM, nil, origin: origem)
                               .reject { |u| viewer.excluded_user_ids.include?(u[:id]) }
    puts "Aparecem no mapa agora (#{aparecem.size}):"
    aparecem.each { |u| puts "  ✓ #{u[:username] || u[:id]} (id #{u[:id]}) — #{(u[:distance_km] * 1000).round} m" }
    puts "  ninguém" if aparecem.empty?
    puts

    ids_que_aparecem = aparecem.map { |u| u[:id] }
    bloqueados = viewer.excluded_user_ids
    outros = User.where.not(id: [ viewer.id ] + ids_que_aparecem)
                 .order(Arel.sql("last_location_updated_at DESC NULLS LAST"))
                 .limit(limite)

    puts "Não aparecem (as #{limite} contas com localização mais recente):"
    outros.each do |u|
      motivos = []
      motivos << "banida" if u.banned_at.present?
      motivos << "conta congelada" if u.account_frozen?
      motivos << "modo oculto ligado" if u.invisible?
      motivos << "localização em tempo real desligada" unless u.sharing_location?
      motivos << "bloqueio entre as contas" if bloqueados.include?(u.id)
      if u.latitude.blank? || u.longitude.blank?
        motivos << "sem posição salva"
      else
        metros = (Geocoder::Calculations.distance_between(origem, [ u.latitude, u.longitude ]) * 1000).round
        motivos << "longe: #{metros} m (máx. #{(User::MAP_RADIUS_KM * 1000).round} m)" if metros > User::MAP_RADIUS_KM * 1000
      end
      if u.last_location_updated_at.nil?
        motivos << "nunca enviou localização"
      elsif u.last_location_updated_at < 5.minutes.ago
        minutos = ((Time.current - u.last_location_updated_at) / 60).round
        motivos << "offline há #{minutos} min (precisa ter atualizado nos últimos 5)"
      end
      motivos << "motivo não identificado (gênero filtrado no app?)" if motivos.empty?
      puts "  ✗ #{u.username.presence || u.email} (id #{u.id}) — #{motivos.join('; ')}"
    end
  end
end
