// app/javascript/dark_mode_toggle.js

document.addEventListener('turbo:load', () => {
  const toggleButton = document.getElementById('theme-toggle');
  const html = document.documentElement;
  const STORAGE_KEY = 'theme-preference';
  const DARK_MODE_CLASS = 'dark-mode';
  const LIGHT_MODE_CLASS = 'light-mode';

  // 1. Função para aplicar o tema
  const applyTheme = (theme) => {
    if (theme === 'dark') {
      html.classList.add(DARK_MODE_CLASS);
      html.classList.remove(LIGHT_MODE_CLASS);
      if (toggleButton) {
        toggleButton.querySelector('i').className = 'fas fa-sun';
        toggleButton.querySelector('.nav-text').textContent = 'Modo Claro';
      }
    } else {
      html.classList.remove(DARK_MODE_CLASS);
      // .light-mode suprime o .dark injetado pelo iOS quando usuário escolhe light explicitamente
      html.classList.add(LIGHT_MODE_CLASS);
      if (toggleButton) {
        toggleButton.querySelector('i').className = 'fas fa-moon';
        toggleButton.querySelector('.nav-text').textContent = 'Modo Escuro';
      }
    }
  };

  // 2. Função para obter a preferência inicial
  const getPreferredTheme = () => {
    const storedPreference = localStorage.getItem(STORAGE_KEY);
    if (storedPreference) return storedPreference;
    if (window.matchMedia('(prefers-color-scheme: dark)').matches) return 'dark';
    return 'light';
  };

  // 3. Aplica o tema inicial ao carregar a página
  const initialTheme = getPreferredTheme();
  applyTheme(initialTheme);

  // 4. Listener para o botão de alternância
  if (toggleButton) {
    toggleButton.addEventListener('click', () => {
      const currentTheme = html.classList.contains(DARK_MODE_CLASS) ? 'dark' : 'light';
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      applyTheme(newTheme);
      localStorage.setItem(STORAGE_KEY, newTheme);
    });
  }

  // 5. Listener para mudanças na preferência do sistema
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem(STORAGE_KEY)) {
      if (e.matches) {
        html.classList.add(DARK_MODE_CLASS);
        html.classList.remove(LIGHT_MODE_CLASS);
      } else {
        html.classList.remove(DARK_MODE_CLASS);
      }
    }
  });
});
