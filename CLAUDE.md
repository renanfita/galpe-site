# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projeto

Site one-page + painel admin do **Galpê**, buffet infantil em Teresópolis/RJ. HTML/CSS/JS vanilla, **sem etapa de build, sem node_modules, sem framework** — cada página é um arquivo único autocontido (HTML + CSS + JS inline). Deploy estático na Vercel (projeto `galpe-site`, publica automaticamente no push para o GitHub). Idioma do conteúdo, commits e comentários: **português (pt-BR)**.

## Comandos

```bash
# Rodar localmente (ou só abrir index.html no navegador)
python -m http.server 8765   # http://localhost:8765

# Verificação E2E (Playwright + Supabase mockado — ver tests/README.md)
cd tests/e2e && npm install && npx playwright install chromium && npm test

# Deploy: commit + push → Vercel publica sozinha
```

Não há lint. A suíte E2E em `tests/e2e/` (fora do deploy; o **site** segue sem build e sem dependências) cobre os fluxos das cinco páginas — rodar ao mexer em preço, gate, aceite ou assinatura, e cobrir comportamento novo com uma verificação nova. Ajustes visuais: conferir manualmente no navegador (340/390/768/1440px).

## Arquitetura

Cinco páginas + um backend Supabase compartilhado:

- **`index.html`** (site público) — funciona 100% offline do banco: preços embutidos em `var PRICES`. Se `supabase-config.js` estiver configurado, busca preços ao vivo de `precos`, adicionais precificados de `upgrades` e o valor da Comida de verdade de `site_config` via REST. O **simulador fica atrás de um gate de captura de lead** (`form#simGate`): nome + WhatsApp obrigatórios (aniversariante/idade/mês opcionais) → INSERT em `leads` (somente colunas da whitelist anon: `nome, telefone, data_interesse, origem:'site', observacoes`) → revela o simulador (`#simApp`). O simulador trabalha com **contagem exata de pagantes** (input 1–150) enquadrada automaticamente na faixa, meia-entrada 6–9 e adicionais marcáveis, exibindo um mini-extrato — regras na seção *Regras de preço*. Memória em `localStorage` (`galpe_lead` libera retornos sem flash via classe `lead-ok` aplicada pré-paint no `<head>`; `galpe_lead_pendente` guarda lead que falhou por rede e reenvia na visita seguinte). Timeout de 3,5s e qualquer falha **liberam o simulador mesmo assim** — o gate nunca pode travar o funil; sem JS, a classe `.no-js` mostra o simulador estático direto. A mensagem do WhatsApp sai personalizada com nome/aniversariante. O Supabase é progressive enhancement; nunca quebre o fallback estático.
- **`admin.html`** (back-office, login via Supabase Auth) — KPIs + **metas do mês** (`meta_festas_mes`/`meta_receita_mes`), calendário/bloqueio de datas, CRM de leads, gerador de propostas (convidados integrais + meia-entrada 6–9) com **PDF estilizado** (janela de impressão com a marca — `abrirImpressao()`/`PRINT_CSS`), **contratos** (gerados da proposta via `textoContratoTemplate()`, texto editável antes de salvar, numeração de cláusulas dinâmica), **métricas** (funil/origem/conversão/ticket médio/receita 6 meses), editor de preços/upgrades e configurações (incl. razão social/CNPJ/PIX do contrato e ID GA4). Escreve nas tabelas `site_config`, `precos`, `upgrades`, `leads`, `propostas`, `eventos`, `bloqueios`, `contratos`. Se a tabela `contratos` ainda não existir no banco, o painel degrada com instrução na tela (não trava). **Convenções do fluxo comercial:** `ctSave` tem guarda jurídica — bloqueia salvar contrato cujo texto não contém o valor total e a data dos campos (evita assinar texto divergente do resumo; "Regerar" resolve); copiar link anuncia no toast quando promove `rascunho → enviado`; `sendProp`/`sendContrato` abrem o WhatsApp **com o destinatário** (`waNum()` normaliza o telefone do lead/contratante com DDI 55); a meta "Festas fechadas" conta só `reservado/confirmado/realizado` (pré-reserva sem sinal fica de fora).
- **`proposta.html`** — página pública de proposta acessada por token UUID (`?t=...`). Não lê tabelas diretamente: usa as RPCs `get_proposta` e `aceitar_proposta` (security definer) para não expor a tabela `propostas`. Botão "Salvar em PDF" (print CSS).
- **`contrato.html`** — página pública de **assinatura eletrônica** por token (`?t=...`), via RPCs `get_contrato`/`assinar_contrato` (security definer). O cliente assina com nome + CPF (validação de dígitos verificadores) + assinatura **desenhada no canvas OU digitada** (alternativa acessível: renderiza o nome em Fraunces itálico num canvas offscreen — mesmo PNG/hash/trilha). O servidor grava a auditoria: data/hora, IP, user-agent e **hash SHA-256 do texto integral** (MP 2.200-2/2001 art. 10 §2º e Lei 14.063/2020). O comprovante pós-assinatura **fecha o ciclo**: mostra o sinal + a chave PIX (`site_config.pix_chave`) e um botão "Avisar a equipe" (nunca `window.open` automático — popup blocker engole). Só status `enviado` é assinável (rascunho mostra estado neutro creme/navy, não verde); copiar link/enviar WhatsApp no admin promove `rascunho → enviado`; o CPF sai mascarado na RPC pública. O texto do contrato é focável por teclado (`role=region`, medida 75ch).
- **`privacidade.html`** — política de privacidade (LGPD), linkada no gate do simulador, no footer e no banner de cookies.
- **Cookies/GA4 no `index.html`**: banner de consentimento (`#ckBanner`, chave `galpe_consent` no localStorage; "Preferências de cookies" no footer reabre; em ≤760px o banner fica em `bottom:92px` para **não cobrir o botão flutuante de WhatsApp**). O Google Analytics **só carrega com consentimento `all` + `site_config.ga4_id` preenchido** (admin → Ajustes), e revogar o consentimento aciona `window['ga-disable-<ID>']` — a medição **para na sessão corrente**, não só na recarga. Eventos: `generate_lead` (gate) e `clique_whatsapp`. Links de privacidade (gate, banner, footer) abrem em nova aba para não perder formulário/posição. CSP no `vercel.json` já libera os domínios do GA.
- **`supabase-config.js`** — único ponto de configuração do backend (`window.GALPE_SUPABASE = { url, anonKey }`). Carregado pelas páginas com backend.
- **`supabase/migrations/`** — fonte da verdade do schema. A integração GitHub do Supabase aplica automaticamente novos arquivos `*.sql` (ordem pelo timestamp do nome) a cada push na branch de produção. **Mudança de schema = novo arquivo timestampado aqui; nunca editar migração já aplicada.** `supabase/config.toml` e `seed.sql` valem para preview branches.
- **`setup/setup.sql`** — instalador manual all-in-one (idempotente), usado só para ativar um projeto Supabase do zero fora da integração (guia em `setup/SETUP-ADMIN.md`). Ao mudar o schema, manter este arquivo em sincronia com as migrações.
- **Modelo de RLS** (pós-hardening): anônimo lê `site_config`/`precos`/`upgrades` e insere em `leads` (colunas restritas, throttle); escrita administrativa exige `public.is_admin()` (tabela `admins`), não apenas estar autenticado. Novos usuários admin precisam ser inseridos em `public.admins`. **Padrões de performance das policies** (migração `20260612150000_perf_rls_lints`, advisor zerado): nas tabelas de leitura pública (`site_config`/`precos`/`upgrades`) a policy de admin cobre **só escrita** (`INSERT`/`UPDATE`/`DELETE` separados — a leitura vem da `*_read`, evitando duas policies permissivas no mesmo `SELECT`); e todo `auth.uid()`/`public.is_admin()` dentro de policy fica embrulhado em `(select …)` (vira InitPlan, avaliado 1× por consulta, não por linha). Ao criar policy nova, repetir os dois padrões para não reintroduzir os lints `multiple_permissive_policies`/`auth_rls_initplan`.

## Regras de preço (aplicar igualmente em simulador, admin e proposta)

Regras confirmadas com o negócio em 11/06/2026. Implementadas em três lugares que **devem permanecer idênticos**: `index.html` (`faixaDe()` + `update()`), `admin.html` (`precoSugerido()` + `calcProp()` + `propTotal()`) e `proposta.html` (render do investimento).

- **Faixas** 60/80/100/150 por dia (tabela `precos`): enquadramento pelo **piso dos convidados integrais** (73 → faixa 60–79). Abaixo de 60 vale o valor da faixa mínima; o site limita o input a 150 (capacidade anunciada). O total multiplica a contagem **exata** (73 × valor da faixa), nunca o piso.
- **Meia-entrada:** crianças de 6 a 9 pagam **50% do valor da faixa** e **não contam** para o enquadramento. Até 5 anos não pagam. Coluna `convidados_meia` em `propostas` (migração `20260611150000`).
- **Adicionais:** `por_pessoa` cobra integrais + meias; `fixo` soma uma vez. "Comida de verdade" vem de `site_config.comida_verdade_preco` (fallback estático 25) — se existir upgrade homônimo no banco, o preço dele alimenta o item fixo, **sem duplicar**. Upgrades só aparecem no simulador quando o admin define preço.
- **Mínimo contratual de pagantes: em aberto** (ver `PENDENCIAS.md`) — hoje não há piso de cobrança em nenhum dos lados.

## Modelo de segurança (não violar)

- A `anon key` é pública por design (RLS protege os dados). A `service_role` key **nunca** entra no front-end nem no repositório.
- Credenciais reais ficam em `.env.local` (gitignorado). Não commitar segredos.
- Acesso a propostas e contratos públicos sempre via RPC com token, nunca select direto na tabela. A RPC `assinar_contrato` valida nome/CPF/formato da assinatura no servidor e calcula o hash sobre o texto salvo no banco (nunca confiar no cliente).
- LGPD: analytics só com consentimento; a política de privacidade (`privacidade.html`) lista os dados/cookies — atualizar ao coletar qualquer dado novo.
- Cadeia de suprimentos: os scripts de CDN (GSAP no `index.html`; supabase-js em `admin`/`proposta`/`contrato`) carregam com `integrity` (SRI sha384) + `crossorigin`, e a CSP do `vercel.json` restringe os hosts. Ao trocar a versão de uma lib, recalcular o hash (ver linha do SRI na tabela de manutenção) — sem isso o navegador bloqueia o script.
- Acesso ao painel: signups públicos do Supabase Auth ficam **desativados** (qualquer autenticado teria acesso total) e a política de senha do provider Email é forte; o *leaked password protection* exige plano Pro (ver `setup/SETUP-ADMIN.md`).

## Manutenção frequente

| O quê | Onde |
| --- | --- |
| Preços (fallback estático) | `index.html` → `var PRICES` |
| Preços (produção) | painel admin ou tabela `precos` no Supabase |
| Campos/copy do gate de leads | `index.html` → `form#simGate` (HTML) + bloco JS `gate de captura do simulador` |
| Preço da Comida de verdade / upgrades | painel admin (Configurações `comida_verdade_preco` / tabela `upgrades`) |
| Telefone/WhatsApp | buscar `5521995060184` em todos os arquivos |
| Cardápio | `index.html` → seção `<!-- ======= CARDÁPIO ======= -->` |
| Fotos | `assets/` (WebP servido no site; manter o .jpg correspondente — usado no og:image) |
| Texto-modelo do contrato | `admin.html` → `textoContratoTemplate()` (o texto salvo é editável por contrato) |
| Metas do painel / ID GA4 / dados do contrato (CNPJ, PIX) | painel admin → Ajustes (chaves `meta_*`, `ga4_id`, `razao_social`, `cnpj`, `pix_chave` — a chave PIX entra no contrato gerado **e** no comprovante pós-assinatura) |
| Política de privacidade / banner de cookies | `privacidade.html` / `index.html` → `#ckBanner` + bloco JS `cookies (LGPD)` |
| Headers de segurança/CSP/cache | `vercel.json` |
| Versão das libs de CDN (GSAP/supabase-js) | tags `<script integrity>` nas páginas — ao subir versão, recalcular o SRI com os bytes do pacote npm (`openssl dgst -sha384 -binary arq.js \| openssl base64 -A`) e apontar para um arquivo exato do pacote (nunca `.min.js` auto-gerado pelo jsdelivr, que pode mudar de bytes) |
| Schema, RLS e RPCs do banco | `supabase/migrations/*.sql` (novo arquivo timestampado; **nunca** editar migração já aplicada) + `setup/setup.sql` idempotente mantido em sincronia. Conferir lints depois de mudar policy (Supabase → Advisors) |
| Config de Auth do Supabase (signups, política de senha) | Dashboard → Authentication (não versionado; passo a passo em `setup/SETUP-ADMIN.md` Passo 4) |
| SEO técnico | `robots.txt`, `sitemap.xml` (atualizar URLs ao migrar para festanogalpe.com.br) |
| Pendências abertas | `PENDENCIAS.md` (atualizar ao concluir qualquer item) |

## Convenções de front-end

- Paleta da marca: creme `#F5EDDC`, marinho `#153765`, laranja `#D85427`, oliva `#A9A22F`. Variantes AA do mesmo matiz (não trocar por causa de contraste): `--orange-btn #C7481C` (superfícies com texto branco), `--orange-ink #B23F15` (texto laranja pequeno sobre os cremes), `--wa #157A3C` (exclusivo de ações WhatsApp). O `#D85427` original fica nos usos grandes/gráficos (títulos display, logo, formas).
- Mobile-first; toda `<img>` com `width`/`height` explícitos (zero layout shift); alvos de toque ≥44px.
- Acessibilidade já implementada — preservar ao editar: ARIA tabs completo no cardápio (roving tabindex + setas), focus trap no lightbox **e** no menu mobile (Esc fecha, foco gerenciado), `:focus-visible` global, `scroll-behavior:smooth` atrás de `prefers-reduced-motion`, landmark `<main>`, texto do contrato focável + assinatura digitada como alternativa ao canvas, tabelas da privacidade com rótulos `data-label` no mobile.
- SEO local é prioridade: manter JSON-LD (`EventVenue`, `FAQPage`) e Open Graph sincronizados com qualquer mudança de conteúdo/preço. O FAQ visível e o bloco `FAQPage` devem permanecer idênticos.
- Contexto de design (impeccable): `PRODUCT.md`, `DESIGN.md` e `DESIGN.json` na pasta acima do repositório (`F:\Galpe\`).
