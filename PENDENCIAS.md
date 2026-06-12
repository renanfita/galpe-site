# Pendências — Site Galpê

> Atualizado em **12/06/2026** (sessões: auditoria swarm → impeccable audit/polish/critique → gate de captura de leads → ferramental admin completo: contratos + assinatura eletrônica, PDF, métricas/metas, GA4/cookies/LGPD).
> Regra de uso: ao concluir um item, marque `[x]` e mova para o histórico no fim do arquivo (com a data). Itens novos entram na seção certa com responsável.
> Este arquivo não vai para o deploy (`.vercelignore` exclui `*.md`).

## 🔐 Segurança e infraestrutura — responsável: Renan

- [ ] **Rotacionar senhas do `.env.local`** (`GALPE_ADMIN_PASSWORD` + senha do Postgres) e **mover o arquivo para fora da pasta do projeto**. Pendente desde a auditoria de 11/06 — as credenciais chegaram a ficar no diretório de deploy antes do `.vercelignore`.
- [ ] **Confirmar o hardening aplicado no Supabase.** A migração está em `supabase/migrations/` (a integração GitHub aplica no push), mas a aplicação nunca foi verificada. Checar no SQL Editor: `select public.is_admin();` funciona e as policies de `leads` exigem colunas restritas. Se a integração não estiver ativa, rodar `setup/setup.sql` inteiro (idempotente). Após criar novo usuário admin, rodar de novo o `insert into public.admins…`.
- [ ] **Dashboard Supabase:** desativar signups públicos + ativar leaked password protection.
- [ ] **Teste pós-deploy do back-office:** login do admin e um link real de proposta (`proposta.html?t=…`) — a CSP do `vercel.json` foi mapeada de todos os recursos, mas nunca testada com fluxo real. Incluir no teste: criar uma proposta **com crianças 6–9 (meia)** e abrir o link público (a coluna `convidados_meia` chegou na migração `20260611150000_convidados_meia.sql` — conferir que foi aplicada junto com as demais). **Incluir também o fluxo novo:** a migração `20260612090000_contratos_metricas_lgpd.sql` (tabela `contratos` + RPCs `get_contrato`/`assinar_contrato`) — gerar um contrato no painel, abrir `contrato.html?t=…` e assinar de teste. *(Todo o fluxo foi validado em 12/06 num Postgres local simulando o Supabase + E2E de navegador com 55 verificações; falta só a confirmação no projeto real, que estava fora da rede da sessão.)*
- [ ] **SRI nos CDNs:** gerar hashes `integrity` para GSAP `3.12.5` (gsap.min.js + ScrollTrigger.min.js, cdnjs) e supabase-js `2.106.2` (jsdelivr) e adicionar nas tags (`index.html`, `admin.html`, `proposta.html`, `contrato.html`). A CSP já restringe os hosts; o SRI é o refinamento que falta. *Tentado em 12/06 numa sessão remota: a política de rede bloqueia cdnjs/jsdelivr (403) — liberar `cdnjs.cloudflare.com`, `cdn.jsdelivr.net` e `api.cdnjs.com` no ambiente do Claude Code on the web, ou gerar localmente com `openssl dgst -sha384 -binary arquivo.js | openssl base64 -A`.*

## 🌐 Domínio e presença local — responsável: Renan/cliente

- [ ] **Registrar `festanogalpe.com.br`** (Registro.br) → trocar todas as URLs `galpe-site.vercel.app` (canonical, og/twitter, JSON-LD, `robots.txt`, `sitemap.xml`) e configurar redirect 301 do domínio Vercel.
- [ ] **Google Business Profile** com o endereço da Rua Yeda, 184 + link do site (pré-requisito do item de prova social abaixo).
- [ ] **Link do site na bio do Instagram** @festanogalpe.

## 📋 Conteúdo — responsável: cliente fornece, dev integra

- [ ] **Prova social:** 1–2 depoimentos reais curtos de pais OU a nota do Google Business → vira uma faixa única entre `#precos` e `#faq` (estilo sticker/team-strip da casa). *Nunca inventado* — aguardando material real. (Achado P2 do critique: zero prova social numa decisão movida a confiança.)
- [ ] **Regra de desistência para menos de 60 dias:** o FAQ hoje diz só "até 60 dias antes, ressarcimos 70%" e deixa o pior cenário à imaginação do leitor. Completar a resposta em `index.html` (FAQ visível **e** o bloco JSON-LD `FAQPage` no `<head>` — manter os dois idênticos). Moldura sugerida: *"Após esse prazo, [regra real — ex.: buscamos remarcar sua festa conforme a agenda]"*.
- [ ] **Foto real do prato da aba "Comida de verdade"** (strogonoff/mini porção da casa). Hoje a aba usa `familia-mesa.webp` (real, mas repetida da galeria). Ao trocar: atualizar `src`, `width/height` e `alt`, e **apagar `comida-verdade.webp` + `comida-verdade.jpg`** (órfãos em `assets/` — era foto stock com alt incorreto).
- [ ] **Revisar o texto-modelo do contrato com o Galpê (idealmente um advogado).** O gerador (`admin.html` → `textoContratoTemplate()`) usa as regras públicas do site (sinal, saldo 10 dias antes, desistência 60 dias/70%, hora extra, meia-entrada) + cláusulas padrão (imagem, LGPD, força maior, foro Teresópolis). O texto é editável contrato a contrato, mas o modelo merece um aval jurídico antes do primeiro uso real.
- [ ] **Preencher em Ajustes:** razão social, CNPJ e chave PIX (entram no contrato gerado) + metas de festas/receita do mês (alimentam o painel).
- [ ] **Criar a propriedade GA4** (analytics.google.com, conta do Galpê) e colar o ID em Ajustes → Metas & medição. O site só mede com consentimento do banner de cookies; eventos já instrumentados: `generate_lead` e `clique_whatsapp`.
- [ ] **Mínimo contratual de pagantes — perguntar ao Galpê.** Desde a contagem exata (commit `6ed959a`), o simulador aceita qualquer quantidade: 45 pagantes simulam a R$ 134 cada (valor da faixa mínima), e o admin também aceita qualquer número no gerador de propostas. Se o contrato exigir um mínimo faturado (ex.: cobrar sempre ao menos 60 pagantes), codificar a regra nos dois lados: simulador (piso de cobrança + legenda explicando, ex. "festas têm mínimo de 60 pagantes") e admin/proposta (`calcProp`/`propTotal` com o mesmo piso). Se não houver mínimo, marcar este item como resolvido sem mudança de código.

## 🧹 Refinos P3 do audit+critique de 12/06 — responsável: dev (lista curta, baixo risco)

- [ ] `window.open(wa.me)` disparado após a RPC de assinatura pode ser engolido por popup blocker (`contrato.html`) → virar botão "Avisar a equipe" dentro do badge de sucesso (e considerar mostrar ali o sinal + chave PIX, fechando o ciclo).
- [ ] Copiar link promove rascunho→enviado em silêncio (`admin.html` `copyContratoLink`) → toast "contrato liberado para assinatura".
- [ ] `sendContrato` abre `wa.me/?text=` sem destinatário tendo `contratante_telefone` no registro.
- [ ] Link de privacidade do gate navega na mesma aba (perde o formulário) → `target="_blank" rel="noopener"`.
- [ ] Meta "Festas fechadas" conta `pre_reserva` sem sinal → contar só reservado/confirmado/realizado.
- [ ] Recusar cookies depois de aceitar não descarrega o GA na sessão corrente (só na recarga).
- [ ] Vocabulário de erro do `contrato.html` (`.erro`) fora do padrão DESIGN.md; estado público "rascunho" usa verde de sucesso → neutro creme/navy.
- [ ] Privacidade mobile: tabelas perdem rótulos (`th{display:none}`) → `td::before{content:attr(data-label)}`; medida >75ch.
- [ ] Headings h1→h3 no admin (4×) e hierarquia tipográfica achatada na privacidade.

## 📈 Funil e produto — decidir com dados

- [ ] **Tempo de resposta aos leads `novo`:** cada liberação do simulador vira lead no CRM do admin — o interesse de quem acabou de simular é perecível; definir rotina de resposta (meta sugerida: < 1h em horário comercial).
- [ ] **Lacuna 60/80/100/150 no simulador:** quem quer 75 convidados clica onde? Avaliar com os leads acumulados se vale um patamar intermediário.

## ✅ Histórico de concluídos (rastreio)

- **12/06/2026 (tarde)** — Pós-merge: **bug do aceite de proposta** corrigido (copiar link no admin agora promove `rascunho → enviada`, igual aos contratos — a RPC pós-hardening só aceita `enviada`; propostas antigas em rascunho: clicar 🔗 uma vez no admin promove); **robustez da `proposta.html`** (mensagem inline no lugar do `alert`, handler de queda de rede — botão não trava mais em "Enviando…" —, aviso de proposta vencida/indisponível no lugar do botão); **scrollspy** no nav do `index.html` (desktop + menu mobile, `aria-current`); **passada de design no `admin.html`** (variantes AA `--orange-btn`/`--orange-ink`, `:focus-visible` global, alvos de toque 44px no mobile, inputs 16px anti-zoom iOS, `prefers-reduced-motion`, toast com `aria-live`); **suíte E2E commitada em `tests/e2e/`** (Playwright + Supabase mockado, ~75 verificações, fora do deploy).
- **12/06/2026** — Audit+critique rodada 2 (P1+P2): banner de cookies sobe acima do WhatsApp no mobile; "não encontrado" de contrato e proposta com saída de WhatsApp; `main{min-width:0}` corrige estouro do admin mobile (603→390px); admin na paleta AA (`--ok #157A3C`, chip de proposta, nav ativa, dia de hoje); guard jurídico no `ctSave` (texto deve conter valor/data dos campos); One Green Rule no contrato (Assinar laranja, WhatsApp verde sólido); a11y do contrato (texto focável `role=region`, 75ch) + **assinatura digitada** como alternativa ao desenho (Fraunces itálico, mesmo hash/auditoria). 11 verificações comportamentais via Playwright.
- **12/06/2026** — Ferramental admin ponta a ponta: **contratos com assinatura eletrônica** (tabela `contratos` + RPCs com trilha de auditoria SHA-256/IP/data, página pública `contrato.html` com canvas de assinatura e validação de CPF), **PDF estilizado** de proposta e contrato (janela de impressão com a marca), **métricas e metas** (funil, origem, conversão, ticket médio, receita 6 meses, metas de festas/receita no dashboard), **LGPD** (página `privacidade.html`, banner de cookies com consentimento, link no gate e no footer) e **GA4 opt-in** (ID configurável em Ajustes, eventos `generate_lead`/`clique_whatsapp`, CSP atualizada). Validação: migração + setup.sql testados em Postgres local simulando Supabase (RLS, assinatura, reassinatura bloqueada, CPF mascarado) e E2E de navegador com 55 verificações em todas as páginas.
- **11/06/2026** — Auditoria swarm: XSS na proposta, headers/CSP (`vercel.json`), RLS hardening (migração), hero sem dependência de CDN, robots/sitemap, WebP (−36% de peso). Detalhes em `RELATORIO-AUDITORIA.md`.
- **11/06/2026** — Impeccable audit/polish (commit `6911c04`): paleta AA (`--orange-btn`/`--orange-ink`/`--wa`), landmark `<main>`, ARIA tabs completo, focus trap no lightbox e menu mobile, simulador com resultado visível no toque, foto stock removida, `tel:`, footer h3.
- **11/06/2026** — Gate de captura de leads no simulador (commit `d0eade2`): dados antes do preço, lead no CRM, memória no aparelho, reenvio de pendentes, WhatsApp personalizado. Contexto de design em `../PRODUCT.md` e `../DESIGN.md`.
