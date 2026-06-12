# Testes E2E — Galpê

Suíte de verificação de navegador (Playwright + Chromium) com o Supabase **mockado**
(`mock-supabase.js` substitui o CDN do supabase-js; nenhuma rede externa é usada).
Cobre as cinco páginas: gate de leads + simulador + cookies/GA4 do `index.html`,
fluxo completo do `admin.html` (login, proposta, PDF, contrato, métricas, ajustes),
aceite e estados de falha da `proposta.html`, assinatura no canvas do `contrato.html`
e a `privacidade.html`.

> Convenção do projeto: o **site** continua sem build e sem dependências.
> Esta pasta é só ferramenta de desenvolvimento — `.vercelignore` a exclui do deploy
> e `node_modules/` é gitignorado.

## Rodar

```bash
cd tests/e2e
npm install            # instala o playwright (uma vez)
npx playwright install chromium
npm test               # ~30s, imprime OK/FALHA por verificação
```

Sai com código 0 quando todas as verificações passam. Falhas listam a página e a
verificação exata. Erros de JS de qualquer página também reprovam a suíte.

## Estrutura

| Arquivo | Papel |
| --- | --- |
| `run.js` | Suíte única: sobe um servidor estático local e dirige o Chromium |
| `mock-supabase.js` | Mock UMD do supabase-js (tabelas em memória + RPCs configuráveis; `{__reject:true}` simula queda de rede) |

Ao mexer em regra de preço, gate, aceite de proposta ou assinatura de contrato,
rode a suíte e acrescente uma verificação cobrindo o novo comportamento.
