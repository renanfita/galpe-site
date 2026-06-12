# Pendências — Site Galpê

> Atualizado em **11/06/2026** (sessões: auditoria swarm → impeccable audit/polish/critique → gate de captura de leads).
> Regra de uso: ao concluir um item, marque `[x]` e mova para o histórico no fim do arquivo (com a data). Itens novos entram na seção certa com responsável.
> Este arquivo não vai para o deploy (`.vercelignore` exclui `*.md`).

## 🔐 Segurança e infraestrutura — responsável: Renan

- [ ] **Rotacionar senhas do `.env.local`** (`GALPE_ADMIN_PASSWORD` + senha do Postgres) e **mover o arquivo para fora da pasta do projeto**. Pendente desde a auditoria de 11/06 — as credenciais chegaram a ficar no diretório de deploy antes do `.vercelignore`.
- [ ] **Confirmar o hardening aplicado no Supabase.** A migração está em `supabase/migrations/` (a integração GitHub aplica no push), mas a aplicação nunca foi verificada. Checar no SQL Editor: `select public.is_admin();` funciona e as policies de `leads` exigem colunas restritas. Se a integração não estiver ativa, rodar `setup/setup.sql` inteiro (idempotente). Após criar novo usuário admin, rodar de novo o `insert into public.admins…`.
- [ ] **Dashboard Supabase:** desativar signups públicos + ativar leaked password protection.
- [ ] **Teste pós-deploy do back-office:** login do admin e um link real de proposta (`proposta.html?t=…`) — a CSP do `vercel.json` foi mapeada de todos os recursos, mas nunca testada com fluxo real. Incluir no teste: criar uma proposta **com crianças 6–9 (meia)** e abrir o link público (a coluna `convidados_meia` chegou na migração `20260611150000_convidados_meia.sql` — conferir que foi aplicada junto com as demais).
- [ ] **SRI nos CDNs:** gerar hashes `integrity` para GSAP `3.12.5` (gsap.min.js + ScrollTrigger.min.js, cdnjs) e supabase-js `2.106.2` (jsdelivr) e adicionar nas tags. A CSP já restringe os hosts; o SRI é o refinamento que falta.

## 🌐 Domínio e presença local — responsável: Renan/cliente

- [ ] **Registrar `festanogalpe.com.br`** (Registro.br) → trocar todas as URLs `galpe-site.vercel.app` (canonical, og/twitter, JSON-LD, `robots.txt`, `sitemap.xml`) e configurar redirect 301 do domínio Vercel.
- [ ] **Google Business Profile** com o endereço da Rua Yeda, 184 + link do site (pré-requisito do item de prova social abaixo).
- [ ] **Link do site na bio do Instagram** @festanogalpe.

## 📋 Conteúdo — responsável: cliente fornece, dev integra

- [ ] **Prova social:** 1–2 depoimentos reais curtos de pais OU a nota do Google Business → vira uma faixa única entre `#precos` e `#faq` (estilo sticker/team-strip da casa). *Nunca inventado* — aguardando material real. (Achado P2 do critique: zero prova social numa decisão movida a confiança.)
- [ ] **Regra de desistência para menos de 60 dias:** o FAQ hoje diz só "até 60 dias antes, ressarcimos 70%" e deixa o pior cenário à imaginação do leitor. Completar a resposta em `index.html` (FAQ visível **e** o bloco JSON-LD `FAQPage` no `<head>` — manter os dois idênticos). Moldura sugerida: *"Após esse prazo, [regra real — ex.: buscamos remarcar sua festa conforme a agenda]"*.
- [ ] **Foto real do prato da aba "Comida de verdade"** (strogonoff/mini porção da casa). Hoje a aba usa `familia-mesa.webp` (real, mas repetida da galeria). Ao trocar: atualizar `src`, `width/height` e `alt`, e **apagar `comida-verdade.webp` + `comida-verdade.jpg`** (órfãos em `assets/` — era foto stock com alt incorreto).
- [ ] **Política de privacidade (LGPD):** o gate do simulador captura nome/WhatsApp ativamente. Criar página ou seção e linkar na microcopy do gate (`.gate-lgpd`) e no footer.
- [ ] **Mínimo contratual de pagantes — perguntar ao Galpê.** Desde a contagem exata (commit `6ed959a`), o simulador aceita qualquer quantidade: 45 pagantes simulam a R$ 134 cada (valor da faixa mínima), e o admin também aceita qualquer número no gerador de propostas. Se o contrato exigir um mínimo faturado (ex.: cobrar sempre ao menos 60 pagantes), codificar a regra nos dois lados: simulador (piso de cobrança + legenda explicando, ex. "festas têm mínimo de 60 pagantes") e admin/proposta (`calcProp`/`propTotal` com o mesmo piso). Se não houver mínimo, marcar este item como resolvido sem mudança de código.

## 📈 Funil e produto — decidir com dados

- [ ] **Tempo de resposta aos leads `novo`:** cada liberação do simulador vira lead no CRM do admin — o interesse de quem acabou de simular é perecível; definir rotina de resposta (meta sugerida: < 1h em horário comercial).
- [ ] **Lacuna 60/80/100/150 no simulador:** quem quer 75 convidados clica onde? Avaliar com os leads acumulados se vale um patamar intermediário.
- [ ] (Opcional) **Scrollspy/estado ativo no nav** — one-page de ~14.500px no mobile sem indicação de "onde estou".
- [ ] (Opcional) **Passada de design no `admin.html`** (registro *product* — nunca recebeu o polish do impeccable; só a auditoria de segurança).

## ✅ Histórico de concluídos (rastreio)

- **11/06/2026** — Auditoria swarm: XSS na proposta, headers/CSP (`vercel.json`), RLS hardening (migração), hero sem dependência de CDN, robots/sitemap, WebP (−36% de peso). Detalhes em `RELATORIO-AUDITORIA.md`.
- **11/06/2026** — Impeccable audit/polish (commit `6911c04`): paleta AA (`--orange-btn`/`--orange-ink`/`--wa`), landmark `<main>`, ARIA tabs completo, focus trap no lightbox e menu mobile, simulador com resultado visível no toque, foto stock removida, `tel:`, footer h3.
- **11/06/2026** — Gate de captura de leads no simulador (commit `d0eade2`): dados antes do preço, lead no CRM, memória no aparelho, reenvio de pendentes, WhatsApp personalizado. Contexto de design em `../PRODUCT.md` e `../DESIGN.md`.
