# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projeto

Site one-page + painel admin do **Galpê**, buffet infantil em Teresópolis/RJ. HTML/CSS/JS vanilla, **sem etapa de build, sem node_modules, sem framework** — cada página é um arquivo único autocontido (HTML + CSS + JS inline). Deploy estático na Vercel (projeto `galpe-site`, publica automaticamente no push para o GitHub). Idioma do conteúdo, commits e comentários: **português (pt-BR)**.

## Comandos

```bash
# Rodar localmente (ou só abrir index.html no navegador)
python -m http.server 8765   # http://localhost:8765

# Deploy: commit + push → Vercel publica sozinha
```

Não há lint nem testes automatizados. Verificação é manual no navegador (testar em 340/390/768/1440px).

## Arquitetura

Três páginas + um backend Supabase compartilhado:

- **`index.html`** (site público) — funciona 100% offline do banco: preços embutidos em `var PRICES` (~linha 890). Se `supabase-config.js` estiver configurado, busca preços ao vivo de `precos` via REST e grava leads do simulador na tabela `leads`. O Supabase é progressive enhancement; nunca quebre o fallback estático.
- **`admin.html`** (back-office, login via Supabase Auth) — KPIs, calendário/bloqueio de datas, CRM de leads, gerador de propostas, editor de preços/upgrades e configurações. Escreve nas tabelas `site_config`, `precos`, `upgrades`, `leads`, `propostas`, `eventos`, `bloqueios`.
- **`proposta.html`** — página pública de proposta acessada por token UUID (`?t=...`). Não lê tabelas diretamente: usa as RPCs `get_proposta` e `aceitar_proposta` (security definer) para não expor a tabela `propostas`.
- **`supabase-config.js`** — único ponto de configuração do backend (`window.GALPE_SUPABASE = { url, anonKey }`). Carregado pelas três páginas.
- **`setup/setup.sql`** — schema completo, idempotente (pode rodar de novo). RLS em todas as tabelas: anônimo só lê `site_config`/`precos`/`upgrades` e só insere em `leads`; todo o resto exige usuário autenticado. Mudanças de schema vão aqui, mantendo a idempotência. Guia de ativação em `setup/SETUP-ADMIN.md`.

## Modelo de segurança (não violar)

- A `anon key` é pública por design (RLS protege os dados). A `service_role` key **nunca** entra no front-end nem no repositório.
- Credenciais reais ficam em `.env.local` (gitignorado). Não commitar segredos.
- Acesso a propostas públicas sempre via RPC com token, nunca select direto na tabela.

## Manutenção frequente

| O quê | Onde |
|---|---|
| Preços (fallback estático) | `index.html` → `var PRICES` |
| Preços (produção) | painel admin ou tabela `precos` no Supabase |
| Telefone/WhatsApp | buscar `5521995060184` em todos os arquivos |
| Cardápio | `index.html` → seção `<!-- ======= CARDÁPIO ======= -->` |
| Fotos | `assets/` (WebP servido no site; manter o .jpg correspondente — usado no og:image) |
| Headers de segurança/CSP/cache | `vercel.json` |
| SEO técnico | `robots.txt`, `sitemap.xml` (atualizar URLs ao migrar para festanogalpe.com.br) |

## Convenções de front-end

- Paleta da marca: creme `#F5EDDC`, marinho `#153765`, laranja `#D85427`, oliva `#A9A22F`.
- Mobile-first; toda `<img>` com `width`/`height` explícitos (zero layout shift).
- Acessibilidade já implementada (ARIA tabs no cardápio, lightbox navegável por teclado, `:focus-visible`) — preservar ao editar.
- SEO local é prioridade: manter JSON-LD (`EventVenue`, `FAQPage`) e Open Graph sincronizados com qualquer mudança de conteúdo/preço.
