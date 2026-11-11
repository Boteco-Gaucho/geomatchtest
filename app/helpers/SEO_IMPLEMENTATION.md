# 🎯 Guia de Implementação SEO - GeoMatch

## 📋 Schemas Disponíveis no Helper

### 1. **SoftwareApplication + LocalBusiness** (Automático)
Renderizado em toda página via `render_schema_json` no layout.

```ruby
# Saída automática:
# - SoftwareApplication: nome, descrição, rating, downloads
# - LocalBusiness: endereço do Brasil, telefone, email
```

---

### 2. **FAQ Schema** (Em Páginas de Suporte/Help)

```erb
<!-- Em app/views/pages/suporte.html.erb (já implementado) -->
<script type="application/ld+json">
<%= {
  "@context": "https://schema.org/",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Pergunta aqui?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Resposta aqui."
      }
    }
  ]
}.to_json %>
</script>
```

**Onde usar**: /suporte, /faq, páginas de help

---

### 3. **Breadcrumb Schema** (Em Todas as Páginas)

```erb
<!-- Em app/views/pages/landing.html.erb (já implementado) -->
<script type="application/ld+json">
<%= {
  "@context": "https://schema.org/",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://geomatchbr.com/" },
    { "@type": "ListItem", "position": 2, "name": "Planos", "item": "https://geomatchbr.com/plans" }
  ]
}.to_json %>
</script>
```

**Onde usar**: Toda página com navegação hierárquica

---

### 4. **Article Schema** (Para Blog Posts)

```erb
<!-- Exemplo para future blog_posts/show.html.erb -->
<script type="application/ld+json">
<%= {
  "@context": "https://schema.org/",
  "@type": "Article",
  "headline": @post.title,
  "description": @post.excerpt,
  "image": image_url(@post.featured_image),
  "datePublished": @post.published_at.iso8601,
  "dateModified": @post.updated_at.iso8601,
  "author": {
    "@type": "Person",
    "name": @post.author_name
  }
}.to_json %>
</script>
```

---

## 🚀 Como Usar em um Controller

### Setar Metatags Customizadas

```ruby
class BlogPostsController < ApplicationController
  def show
    @post = BlogPost.find(params[:id])
    
    # Sobrescrever metatags padrão para este post
    @seo_tags = {
      title: @post.title,
      description: @post.excerpt,
      image: image_url(@post.featured_image),
      url: blog_post_url(@post),
      og_title: @post.title,
      og_description: @post.excerpt,
      og_image: image_url(@post.featured_image),
      og_type: "article",
      tw_card: "summary_large_image",
      tw_title: @post.title,
      tw_description: @post.excerpt,
      tw_image: image_url(@post.featured_image)
    }
  end
end
```

---

## 📊 Validação de Schemas

### 1. **Google Rich Results Test**
```
https://search.google.com/test/rich-results
```
Colar URL do seu site para validar se os schemas estão corretos.

### 2. **Schema.org Validator**
```
https://validator.schema.org/
```
Validador alternativo.

### 3. **Estruturado de Dados no GSC**
```
https://search.google.com/search-console
→ Melhorias → Dados estruturados
```

---

## 📈 Impacto Esperado

| Schema | Impacto | Timeline |
|--------|---------|----------|
| **SoftwareApplication** | Aparece em knowledge panel | 1-2 semanas |
| **LocalBusiness** | Mapa + horários em busca local | 2-4 semanas |
| **FAQ** | Respostas destacadas em SERPs | 1-3 semanas |
| **Breadcrumb** | Navegação estruturada em SERPs | 1-2 semanas |
| **Article** (blog) | Rich snippets em resultados | 1-2 semanas |

---

## 🔧 Próximos Passos

1. **Blog Model** (bonus): Posts dinâmicos com Article schema
2. **Events Schema**: Para eventos/webinars
3. **Product Schema**: Para planos/preços (Gold plan)
4. **Video Schema**: Se adicionar vídeos de demo
5. **Review Schema**: Se adicionar reviews de usuários

---

## 📝 Checklist de Validação

- [ ] Local Business schema aparece em `view-source` da home
- [ ] FAQ schema válido em /suporte (Google Rich Results Test)
- [ ] Breadcrumbs funcionando em SERPs
- [ ] Meta tags OG corretas (teste no Facebook Debugger)
- [ ] Twitter Card válido (teste no Twitter Card validator)
- [ ] Sitemap.xml listado em robots.txt
- [ ] CSP não bloqueando schemas

