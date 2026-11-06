module PrivacySettingsHelper
  # Tela Privacidade e localização (/privacidade): a política em tópicos curtos.
  # O texto completo (jurídico) continua em /politica-de-privacidade.
  PRIVACY_POLICY_UPDATED_ON = Date.new(2026, 11, 4)
  PRIVACY_CONTACT_EMAIL     = "suporte@geomatch.com.br".freeze

  # [título, parágrafo ou lista de [destaque, texto]] — o 2º tópico abre aberto
  PRIVACY_POLICY_TOPICS = [
    [ "Quem cuida dos seus dados",
      "A GeoMatch LTDA é a controladora dos seus dados: decide como eles são usados e responde por eles, " \
      "seguindo a Lei Geral de Proteção de Dados (LGPD, Lei nº 13.709/2018)." ],
    [ "Que dados coletamos",
      [ [ "Cadastro:", "nome, nascimento, gênero, e-mail, telefone (opcional), fotos e bio." ],
        [ "Perfil:", "interesses, hobbies e o que mais você quiser contar." ],
        [ "Localização:", "usada enquanto o app está aberto, para mostrar quem está a até 300 m." ],
        [ "Uso do app:", "mensagens, tipo de aparelho, IP e cookies." ] ] ],
    [ "Para que usamos",
      "Para o app funcionar (perfil, mapa, curtidas e conversas), para manter todo mundo seguro e evitar " \
      "fraudes, e para cumprir a lei. A localização depende do seu consentimento: você pode desligá-la aqui em cima." ],
    [ "Com quem compartilhamos",
      "Com outras pessoas do app: seu perfil e, no mapa, sua posição aproximada, só para quem está a até 300 m. " \
      "Com empresas que ajudam a operar o app, como hospedagem, armazenamento de fotos, pagamentos (Mercado Pago) " \
      "e notificações. E com autoridades, quando a lei ou a Justiça exigir." ],
    [ "Onde ficam guardados e por quanto tempo",
      "Em servidores que podem ficar fora do Brasil, sempre dentro das regras da LGPD. Guardamos seus dados só " \
      "pelo tempo necessário para o app funcionar ou para cumprir obrigações legais." ],
    [ "Seus direitos pela LGPD",
      "Você pode confirmar se tratamos seus dados, acessá-los, corrigi-los, pedir que sejam anonimizados ou " \
      "apagados, levá-los para outro serviço e retirar seu consentimento quando quiser." ],
    [ "Como protegemos seus dados",
      "Usamos medidas técnicas e administrativas de segurança, e ninguém recebe sua posição exata no mapa. " \
      "Nenhum sistema é 100% seguro, mas trabalhamos para reduzir os riscos." ],
    [ "Menores de 18 anos",
      "O GeoMatch é só para maiores de 18 anos e não coleta, de propósito, dados de menores. " \
      "Viu alguém menor de idade no app? Denuncie o perfil." ]
  ].freeze
end
