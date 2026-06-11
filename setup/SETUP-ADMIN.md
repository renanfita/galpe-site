# 🛠 Ativando o Painel Admin do Galpê

O painel (`admin.html`) gerencia **preços, pacotes, propostas, leads e o calendário de festas** — e alimenta o site público em tempo real. Para ativá-lo são ~10 minutos, uma única vez.

## Passo 1 — Criar o projeto Supabase (grátis)

1. Acesse [supabase.com](https://supabase.com) e crie uma conta (ideal: e-mail do Galpê)
2. **New project** → nome `galpe` → região `South America (São Paulo)` → senha forte do banco (guarde)

## Passo 2 — Rodar o setup do banco

1. No projeto, abra **SQL Editor**
2. Cole o conteúdo inteiro de [`setup.sql`](setup.sql) e clique **Run**
3. Deve terminar sem erros (pode rodar de novo sem problema — é idempotente)

## Passo 3 — Criar o usuário admin

1. **Authentication → Users → Add user → Create new user**
2. E-mail do cliente (ex.: `festanogalpe@gmail.com`) + senha forte
3. Marque **Auto Confirm User**

## Passo 4 — Travar a segurança (CRÍTICO)

1. **Authentication → Sign In / Providers** → desative **"Allow new users to sign up"**
   ⚠️ Sem isso, qualquer pessoa poderia criar conta e acessar o painel.
2. **Authentication → Passwords** → ative **"Leaked password protection"**

## Passo 5 — Conectar o site ao banco

1. **Project Settings → API** → copie a **URL** e a chave **anon (publishable)**
2. Edite [`../supabase-config.js`](../supabase-config.js):

   ```js
   window.GALPE_SUPABASE = {
     url: "https://SEU-PROJETO.supabase.co",
     anonKey: "sb_publishable_..."
   };
   ```

3. Commit + push (a Vercel publica sozinha)

## Pronto! 🎉

- **Painel:** `https://seusite.vercel.app/admin.html`
- O site público passa a usar os **preços do banco** automaticamente
- Cliques em "Garantir minha data" no simulador viram **leads** no painel
- Propostas geram **link público** (`proposta.html?t=...`) para enviar por WhatsApp; o cliente pode **aceitar online**

## O que o admin faz

| Área | Função |
| --- | --- |
| Visão geral | KPIs do mês, próximas festas, pagamentos pendentes |
| Calendário | Festas por mês, status, bloquear datas |
| Leads | CRM: novo → contato → visita → proposta → fechado |
| Propostas | Cálculo automático, upgrades, desconto, link público, aceite online |
| Preços | Tabela dia × convidados (atualiza o site na hora) e upgrades |
| Ajustes | Contatos, regras (sinal %, validade, meia etc.) e troca de senha |

## Segurança (como foi desenhado)

- RLS em todas as tabelas: público só lê preços/config e só cria leads
- Propostas/eventos/leads: somente usuário autenticado
- Link de proposta usa token UUID — sem expor a tabela (via RPC `security definer`)
- A anon key é pública por design; a `service_role` **nunca** é usada no front
