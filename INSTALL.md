# GeoMatch — Landing Page (Rails)

Landing page completa do site (geomatchbr.com), estilo resposta direta:
hero dark + mockup do app, marquees, 8 seções de conteúdo, depoimentos,
GeoMatch Gold e CTA final. Paleta gold/cream/preto da marca.

## Arquivos

| Arquivo do export                | Destino no app Rails                                  |
| -------------------------------- | ----------------------------------------------------- |
| `landing_page.html.erb`          | `app/views/pages/landing.html.erb`                    |
| `landing_page.css`               | `app/assets/stylesheets/landing_page.css`             |
| `landing_controller.js`          | `app/javascript/controllers/landing_controller.js`    |
| `images/geomatch/app-mapa.png`   | `app/assets/images/geomatch/app-mapa.png`             |
| `images/geomatch/app-perfil.png` | `app/assets/images/geomatch/app-perfil.png`           |
| *(você fornece)*                 | `app/assets/images/geomatch/app-chat.png`             |

## Instalação

### 1. Rota + controller

```ruby
# config/routes.rb
root "pages#landing"
```

```ruby
# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  def landing; end
end
```

### 2. CSS

**Sprockets (`application.css`):**
```css
/*
 *= require landing_page
 */
```

**cssbundling-rails (`application.scss`):**
```css
@import "landing_page.css";
```

### 3. Stimulus

Copie `landing_controller.js` para `app/javascript/controllers/`.
Com `stimulus-rails` + importmap, ele é registrado automaticamente
(`bin/rails stimulus:manifest:update` se necessário).

### 4. Fontes

Adicione no `<head>` do `application.html.erb`:

```erb
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Anton&family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
```

- **Anton** — títulos display (uppercase, impacto)
- **Outfit** — corpo e UI (mesma fonte do app)

### 5. Imagem que falta

A seção "Chat instantâneo" referencia `geomatch/app-chat.png`.
Exporte um screenshot real da tela de conversa (720×1346, sem a barra
do sistema) e coloque em `app/assets/images/geomatch/`.

## Estrutura da página

1. **Hero** — headline + mockup do mapa + CTAs App Store / Google Play
2. **Como funciona** — 3 passos numerados
3. **Onde usar** — 6 cards de persona
4. **Conheça o app** — 3 features com screenshots (mapa / chat / bloqueio)
5. **Segurança** — 4 diferenciais + Central de Segurança (Pânico, Denúncia)
6. **Filtro por cidade** — 4 cards de cenário
7. **GeoMatch Gold** — modo invisível + benefícios + preço (R$ 19,99/mês)
8. **Depoimentos** — 6 cards + 2 destaque
9. **Nossa história** — institucional + missão/visão/valores
10. **CTA final + footer**

## Notas

- Tokens de cor em `:root` no topo do CSS (`--gold`, `--cream`, `--black`…).
- Animações respeitam `prefers-reduced-motion`.
- Os links dos botões de download estão como `#` — troque pelas URLs
  reais da App Store / Google Play.
- Preço Gold e depoimentos vêm do documento de conteúdo; ajuste quando
  houver dados reais.
