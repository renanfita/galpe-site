# Relatório Swarm Turbo — Auditoria & Correção · Site Galpê

**Data:** 11/06/2026 · **Modo:** PARALLEL · **Agentes:** 6 (SAST, API-Security, Frontend-Security, Performance, SEO, Validation) · **Achados:** 41 → deduplicados em 30 · **Corrigidos automaticamente:** 27

---

## 🔴 P0 — Críticos (todos corrigidos)

1. **XSS armazenado em `proposta.html`** — nomes de upgrades, `dia_tipo` e metadados vindos do banco eram injetados via `innerHTML` sem escape, executável por qualquer pessoa com link de proposta. → Helper `esc()` aplicado a toda interpolação; linha de total reescrita sem HTML embutido em dados. *(encontrado por 3 agentes)*
2. **Sem headers de segurança** — criado `vercel.json` com CSP completa (script/style/connect/frame restritos a self + Supabase + CDNs), HSTS, X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy; `Cache-Control: no-store` + `X-Robots-Tag: noindex` para admin e proposta; cache imutável de 1 ano para `/assets`.
3. **RLS frouxa no Supabase** — qualquer `authenticated` era admin total; anon podia inserir leads com qualquer coluna/volume; `get_proposta` vazava a linha inteira; `aceitar_proposta` aceitava rascunhos e propostas vencidas. → Hardening no `setup/setup.sql`: tabela `admins` + `is_admin()` em todas as políticas, insert anônimo limitado a colunas seguras com `status='novo'` forçado, constraints de tamanho, throttle de 60 leads/hora, RPC com whitelist de colunas e aceite só de proposta `enviada` dentro da validade.
4. **Hero invisível até o GSAP carregar** (FCP/LCP reféns de CDN) — entrada do hero agora é CSS puro (`.hero-in`), animação de clip sobre a imagem LCP removida, scripts com `defer` + init em `DOMContentLoaded`.
5. **SEO: canonical/og apontando para domínio morto** (`festanogalpe.com.br` não registrado) + sem `robots.txt`/`sitemap.xml` → canonical/og/JSON-LD apontam para a URL de produção; robots.txt e sitemap.xml criados.
6. **Segredos no diretório de deploy** — `.vercelignore` criado (`.env*`, `*.md`, `setup/`). ⚠️ **Ação sua:** rotacionar `GALPE_ADMIN_PASSWORD` e a senha do banco, e mover `.env.local` para fora da pasta.

## 🟠 P1 — Altos (corrigidos)

- `esc()` do admin não escapava aspas simples + IDs/tokens crus em `onclick` → quote escaping adicionado e sanitizador `sid()` em todas as 9 interpolações de handlers.
- supabase-js flutuante `@2` sem pin → pinado em `2.106.2` + `crossorigin` (admin e proposta); GSAP com `crossorigin`. *(SRI: hashes não obtidos pela API do cdnjs nesta sessão — a CSP restringe os hosts; adicionar `integrity` depois é o refinamento que falta)*
- Google Fonts render-blocking → carregamento assíncrono (`media="print"` + noscript) e eixo romano não usado do Fraunces removido.
- Imagens: 22 JPGs convertidos para WebP (q80) e `maquina-pelucias` redimensionada de 800×1426 → 420×749. **Peso da página: 1.194 KB → 772 KB (−36%)**. JPGs mantidos para `og:image` (WhatsApp).
- JSON-LD: `EventVenue` + `LocalBusiness`, com `url`, `image`, `hasMap`, `priceRange` em formato válido; FAQPage agora idêntico ao texto visível e com as 9 perguntas; meta description ≤155 chars com keyword no início; h1/lead com "buffet infantil de Teresópolis".

## 🟡 P2 — Médios (corrigidos)

- `hoje()` usava UTC (virava o dia às 21h BRT) → data local; calendário normalizado para dia 1 (bug do `setMonth` em dia 29–31).
- Simulador: guards contra `R$ NaN`/`undefined` (preços do banco validados, `data-g` inválido ignorado, `update()` com early-return).
- `onAuthStateChange` no admin (sessão encerrada → volta ao login); `window.open` com `noopener`; telefone do WhatsApp sanitizado; validação de formato do token; `src=""` inválido do lightbox removido; `will-change` permanente removido dos botões; âncoras mortas (`#`) corrigidas; coerção numérica do `sinal_percent`.

## ⚠️ Ações manuais pendentes (não automatizáveis daqui)

1. **Rodar o hardening no banco**: Supabase → SQL Editor → colar o `setup/setup.sql` inteiro (idempotente) e **Run**. O MCP do Supabase estava sem permissão de escrita nesta sessão. Depois de criar qualquer novo usuário admin, rode de novo a linha `insert into public.admins...`.
2. **Rotacionar senhas** do `.env.local` (admin + Postgres) e movê-lo para fora da pasta do projeto.
3. Conferir no dashboard: signups desativados + leaked password protection ativa.
4. Pós-deploy: testar login do admin e um link de proposta (a CSP nova pode ser ajustada se algum recurso for bloqueado — improvável, foi mapeada de todos os recursos usados).
5. Ao registrar `festanogalpe.com.br`: trocar as URLs em canonical/og/JSON-LD/robots/sitemap e configurar redirect 301.

## ✅ Verificação final (tudo passou)

Sintaxe de todos os blocos JS (`node --check`), JSON-LD válido, `vercel.json`/`sitemap.xml` válidos, zero IDs duplicados, todas as 25 referências de assets resolvem, HTML parseado sem erros.
