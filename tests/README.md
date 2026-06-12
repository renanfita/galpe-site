# Testes E2E — Galpê

Suíte de verificação de navegador (Playwright + Chromium) com o Supabase **mockado**
(`mock-supabase.js` substitui o CDN do supabase-js; nenhuma rede externa é usada).
Cobre as cinco páginas: gate de leads + simulador + cookies/GA4 do `index.html`,
fluxo completo do `admin.html` (login, proposta, PDF, contrato, métricas, ajustes, sair da conta),
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

Em sandboxes sem acesso ao CDN do Playwright (ex.: Claude Code on the web, onde
só o registry do npm é liberado), use o Chromium empacotado no npm:

```bash
npm i --no-save @sparticuz/chromium
node -e "require('@sparticuz/chromium').default.executablePath().then(console.log)"  # extrai p/ /tmp/chromium
GALPE_E2E_CHROME=/tmp/chromium npm test
```

Nota sobre SRI: as páginas levam `integrity` nas tags de CDN; como o mock nunca
bateria o hash real, o servidor de teste do `run.js` remove o atributo do HTML
servido à suíte (em produção o atributo permanece).

## Estrutura

| Arquivo | Papel |
| --- | --- |
| `run.js` | Suíte única: sobe um servidor estático local e dirige o Chromium |
| `mock-supabase.js` | Mock UMD do supabase-js (tabelas em memória + RPCs configuráveis; `{__reject:true}` simula queda de rede) |

Ao mexer em regra de preço, gate, aceite de proposta ou assinatura de contrato,
rode a suíte e acrescente uma verificação cobrindo o novo comportamento.
