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

- **`index.html`** (site público) — funciona 100% offline do banco: preços embutidos em `var PRICES`. Se `supabase-config.js` estiver configurado, busca preços ao vivo de `precos` via REST. O **simulador fica atrás de um gate de captura de lead** (`form#simGate`): nome + WhatsApp obrigatórios (aniversariante/idade/mês opcionais) → INSERT em `leads` (somente colunas da whitelist anon: `nome, telefone, data_interesse, origem:'site', observacoes`) → revela o simulador (`#simApp`). Memória em `localStorage` (`galpe_lead` libera retornos sem flash via classe `lead-ok` aplicada pré-paint no `<head>`; `galpe_lead_pendente` guarda lead que falhou por rede e reenvia na visita seguinte). Timeout de 3,5s e qualquer falha **liberam o simulador mesmo assim** — o gate nunca pode travar o funil; sem JS, a classe `.no-js` mostra o simulador estático direto. A mensagem do WhatsApp sai personalizada com nome/aniversariante. O Supabase é progressive enhancement; nunca quebre o fallback estático.
- **`admin.html`** (back-office, login via Supabase Auth) — KPIs, calendário/bloqueio de datas, CRM de leads, gerador de propostas, editor de preços/upgrades e configurações. Escreve nas tabelas `site_config`, `precos`, `upgrades`, `leads`, `propostas`, `eventos`, `bloqueios`.
- **`proposta.html`** — página pública de proposta acessada por token UUID (`?t=...`). Não lê tabelas diretamente: usa as RPCs `get_proposta` e `aceitar_proposta` (security definer) para não expor a tabela `propostas`.
- **`supabase-config.js`** — único ponto de configuração do backend (`window.GALPE_SUPABASE = { url, anonKey }`). Carregado pelas três páginas.
- **`supabase/migrations/`** — fonte da verdade do schema. A integração GitHub do Supabase aplica automaticamente novos arquivos `*.sql` (ordem pelo timestamp do nome) a cada push na branch de produção. **Mudança de schema = novo arquivo timestampado aqui; nunca editar migração já aplicada.** `supabase/config.toml` e `seed.sql` valem para preview branches.
- **`setup/setup.sql`** — instalador manual all-in-one (idempotente), usado só para ativar um projeto Supabase do zero fora da integração (guia em `setup/SETUP-ADMIN.md`). Ao mudar o schema, manter este arquivo em sincronia com as migrações.
- **Modelo de RLS** (pós-hardening): anônimo lê `site_config`/`precos`/`upgrades` e insere em `leads` (colunas restritas, throttle); escrita administrativa exige `public.is_admin()` (tabela `admins`), não apenas estar autenticado. Novos usuários admin precisam ser inseridos em `public.admins`.

## Modelo de segurança (não violar)

- A `anon key` é pública por design (RLS protege os dados). A `service_role` key **nunca** entra no front-end nem no repositório.
- Credenciais reais ficam em `.env.local` (gitignorado). Não commitar segredos.
- Acesso a propostas públicas sempre via RPC com token, nunca select direto na tabela.

## Manutenção frequente

| O quê | Onde |
| --- | --- |
| Preços (fallback estático) | `index.html` → `var PRICES` |
| Preços (produção) | painel admin ou tabela `precos` no Supabase |
| Campos/copy do gate de leads | `index.html` → `form#simGate` (HTML) + bloco JS `gate de captura do simulador` |
| Telefone/WhatsApp | buscar `5521995060184` em todos os arquivos |
| Cardápio | `index.html` → seção `<!-- ======= CARDÁPIO ======= -->` |
| Fotos | `assets/` (WebP servido no site; manter o .jpg correspondente — usado no og:image) |
| Headers de segurança/CSP/cache | `vercel.json` |
| SEO técnico | `robots.txt`, `sitemap.xml` (atualizar URLs ao migrar para festanogalpe.com.br) |
| Pendências abertas | `PENDENCIAS.md` (atualizar ao concluir qualquer item) |

## Convenções de front-end

- Paleta da marca: creme `#F5EDDC`, marinho `#153765`, laranja `#D85427`, oliva `#A9A22F`. Variantes AA do mesmo matiz (não trocar por causa de contraste): `--orange-btn #C7481C` (superfícies com texto branco), `--orange-ink #B23F15` (texto laranja pequeno sobre os cremes), `--wa #157A3C` (exclusivo de ações WhatsApp). O `#D85427` original fica nos usos grandes/gráficos (títulos display, logo, formas).
- Mobile-first; toda `<img>` com `width`/`height` explícitos (zero layout shift); alvos de toque ≥44px.
- Acessibilidade já implementada — preservar ao editar: ARIA tabs completo no cardápio (roving tabindex + setas), focus trap no lightbox **e** no menu mobile (Esc fecha, foco gerenciado), `:focus-visible` global, `scroll-behavior:smooth` atrás de `prefers-reduced-motion`, landmark `<main>`.
- SEO local é prioridade: manter JSON-LD (`EventVenue`, `FAQPage`) e Open Graph sincronizados com qualquer mudança de conteúdo/preço. O FAQ visível e o bloco `FAQPage` devem permanecer idênticos.
- Contexto de design (impeccable): `PRODUCT.md`, `DESIGN.md` e `DESIGN.json` na pasta acima do repositório (`F:\Galpe\`).
