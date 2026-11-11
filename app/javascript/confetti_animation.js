import confetti from "canvas-confetti";

// Função para disparar a chuva de corações
function launchConfetti( ) {
  const defaults = {
    spread: 360,
    ticks: 50,
    gravity: 0,
    decay: 0.94,
    startVelocity: 10,
    shapes: ["heart"], // Usar corações como forma
    colors: ["#ff416c", "#ff4b2b", "#ff8c00", "#ff0080"], // Cores de coração
  };

  // Disparo principal (do centro)
  confetti({
    ...defaults,
    particleCount: 50,
    scalar: 1.2,
  });

  // Disparos laterais para efeito de "chuva"
  confetti({
    ...defaults,
    particleCount: 25,
    scalar: 0.75,
    origin: { x: 0.2, y: 0.5 },
  });

  confetti({
    ...defaults,
    particleCount: 25,
    scalar: 0.75,
    origin: { x: 0.8, y: 0.5 },
  });
}

// Função principal para verificar o parâmetro da URL
function checkMatchAndAnimate() {
  // 1. Obter os parâmetros da URL
  const urlParams = new URLSearchParams(window.location.search);
  const isMatch = urlParams.get('match');

  // 2. Verificar se o parâmetro 'match' está presente e é 'true'
  if (isMatch === 'true') {
    // 3. Disparar a animação
    launchConfetti();

    // Opcional: Remover o parâmetro 'match' da URL para que a animação não se repita ao recarregar a página
    // Isso pode ser feito com a API History, mas é mais simples deixar o Turbo/Rails lidar com o estado.
    // Como o `LikesController` sempre redireciona para `lead_path`, o parâmetro será limpo no próximo clique.
  }
}

// O evento 'turbo:load' é o equivalente moderno do 'DOMContentLoaded' para aplicações Turbo (Rails 7+)
document.addEventListener('turbo:render', checkMatchAndAnimate);

// Exportar a função para uso direto, se necessário
export { launchConfetti };