# Site Galpê — Guia rápido

## O que é

Site one-page premium para o **Galpê** (festanogalpe), buffet infantil de Teresópolis/RJ.
Construído com a paleta e identidade da proposta oficial: creme `#F5EDDC`, azul-marinho `#153765`, laranja `#D85427`, oliva `#A9A22F`.

## Como visualizar

Dê dois cliques em `index.html` (precisa de internet para fontes e animações).
Durante esta sessão também está em: <http://localhost:8765/>

## O que tem dentro

- **Hero** com headline da marca e CTAs de WhatsApp
- **O Espaço** (climatizado, fraldário, bar, banheiros)
- **Brinquedão** com todas as atrações + destaque da máquina de pelúcias (foto real do Instagram)
- **Galeria** com lightbox (fotos profissionais da proposta)
- **Cardápio completo** em 8 abas (todas as etapas da festa)
- **Upgrades** ("Quero mais")
- **Simulador de orçamento com captura de lead**: antes de ver valores, o visitante deixa nome + WhatsApp (vira lead no painel admin); depois simula com o número exato de convidados (o sistema enquadra na faixa de preço sozinho), crianças de 6 a 9 a meia e adicionais → mini-extrato com total estimado + mensagem pronta no WhatsApp
- **Como funciona** (4 passos) + equipe
- **FAQ** com as condições gerais reescritas de forma amigável
- **Mapa do Google** apontando para Rua Yeda, 184 + cartões de contato
- Botão flutuante de WhatsApp, animações GSAP, 100% responsivo

## SEO (pronto para dominar o Google local)

- Title/description otimizados para "buffet infantil Teresópolis"
- Schema.org `EventVenue` (endereço, telefone, preços)
- Nenhum concorrente local tem site próprio — oportunidade real de ranquear em 1º

## Como publicar (sugestão)

1. Registrar domínio: `festanogalpe.com.br` (Registro.br, ~R$40/ano)
2. Hospedar grátis: Vercel, Netlify ou Cloudflare Pages (arrastar a pasta `site/`)
3. Criar perfil **Google Business** com o mesmo endereço e linkar o site
4. Colocar o link na bio do Instagram

## Como editar preços

Em `index.html`, procure por `var PRICES` — os valores estão organizados por dia (seg/sex/sab) e nº de convidados.
Com o painel admin ativo, as faixas, o preço da Comida de verdade e os upgrades (que viram adicionais do simulador quando precificados) são editados por lá, sem mexer em código. Crianças de 6 a 9 pagam meia automaticamente; a faixa é definida só pelos pagantes integrais.

## O que ainda falta

Todas as pendências em aberto (senhas, domínio, prova social, política de privacidade etc.) estão centralizadas em **`PENDENCIAS.md`**, com responsável e instruções por item.

## Polimento aplicado (v2)

- Imagens recomprimidas e com `width/height` (zero layout shift); total ~1,4 MB
- `apple-touch-icon.png` + favicon SVG
- Open Graph/Twitter completos com URLs absolutas + JSON-LD `FAQPage`
- Acessibilidade: ARIA em abas/menu/lightbox, navegação por teclado, `:focus-visible`
- Mobile-first revisado em 340/390/768/1440px; menu fullscreen com trava de scroll
- Âncoras com offset do header fixo; fallback que nunca deixa conteúdo invisível

## Estrutura

```text
site/
├── index.html          (site público: HTML + CSS + JS num arquivo)
├── admin.html          (painel back-office com login Supabase)
├── proposta.html       (proposta pública acessada por token)
├── supabase-config.js  (url + anon key do backend)
├── supabase/           (migrações versionadas — fonte da verdade do schema)
├── setup/              (instalador manual + guia SETUP-ADMIN.md)
├── assets/             (imagens otimizadas, WebP + JPG para og:image)
├── vercel.json         (headers de segurança, CSP e cache)
├── robots.txt · sitemap.xml
├── PENDENCIAS.md       (pendências abertas, com responsável)
└── LEIA-ME.md · README.md · CLAUDE.md · RELATORIO-AUDITORIA.md
```
