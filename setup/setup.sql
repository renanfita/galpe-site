-- ============================================================
-- GALPÊ ADMIN — Setup completo do banco (Supabase / Postgres)
-- Cole este arquivo inteiro no SQL Editor do Supabase e execute.
-- Seguro para re-execução (idempotente).
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- 1) Configurações (chave/valor) ----------
create table if not exists public.site_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- ---------- 2) Tabela de preços por dia × convidados ----------
create table if not exists public.precos (
  id serial primary key,
  dia text not null check (dia in ('seg','sex','sab')),
  convidados int not null check (convidados > 0),
  valor numeric(10,2) not null check (valor >= 0),
  unique (dia, convidados)
);

-- ---------- 3) Upgrades / adicionais ----------
create table if not exists public.upgrades (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  descricao text,
  preco numeric(10,2),
  unidade text not null default 'fixo' check (unidade in ('fixo','por_pessoa','por_hora')),
  ativo boolean not null default true,
  ordem int not null default 0
);

-- ---------- 4) Leads (CRM) ----------
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  nome text,
  telefone text,
  origem text not null default 'site',
  status text not null default 'novo'
    check (status in ('novo','contato','visita','proposta','fechado','perdido')),
  data_interesse date,
  convidados int,
  dia_tipo text,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 5) Propostas ----------
create table if not exists public.propostas (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.leads(id) on delete set null,
  token uuid not null unique default gen_random_uuid(),
  nome_cliente text not null,
  aniversariante text,
  idade int,
  tema text,
  data_evento date,
  horario text,
  convidados int not null check (convidados > 0),
  dia_tipo text not null check (dia_tipo in ('seg','sex','sab')),
  valor_pessoa numeric(10,2) not null,
  upgrades jsonb not null default '[]'::jsonb,
  desconto numeric(10,2) not null default 0,
  observacoes text,
  validade date,
  status text not null default 'rascunho'
    check (status in ('rascunho','enviada','aceita','recusada','expirada')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 6) Eventos (calendário) ----------
create table if not exists public.eventos (
  id uuid primary key default gen_random_uuid(),
  proposta_id uuid references public.propostas(id) on delete set null,
  titulo text not null,
  aniversariante text,
  idade int,
  tema text,
  data date not null,
  hora_inicio time not null default '12:00',
  duracao_horas numeric(3,1) not null default 4,
  convidados int,
  valor_total numeric(10,2),
  sinal_pago boolean not null default false,
  saldo_quitado boolean not null default false,
  status text not null default 'reservado'
    check (status in ('pre_reserva','reservado','confirmado','realizado','cancelado')),
  contato_nome text,
  contato_telefone text,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists eventos_data_idx on public.eventos (data);

-- ---------- 7) Datas bloqueadas ----------
create table if not exists public.bloqueios (
  id uuid primary key default gen_random_uuid(),
  data date not null unique,
  motivo text
);

-- ---------- updated_at automático ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_touch_leads on public.leads;
create trigger trg_touch_leads before update on public.leads
  for each row execute function public.touch_updated_at();
drop trigger if exists trg_touch_propostas on public.propostas;
create trigger trg_touch_propostas before update on public.propostas
  for each row execute function public.touch_updated_at();
drop trigger if exists trg_touch_eventos on public.eventos;
create trigger trg_touch_eventos before update on public.eventos
  for each row execute function public.touch_updated_at();

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================
alter table public.site_config enable row level security;
alter table public.precos      enable row level security;
alter table public.upgrades    enable row level security;
alter table public.leads       enable row level security;
alter table public.propostas   enable row level security;
alter table public.eventos     enable row level security;
alter table public.bloqueios   enable row level security;

-- Público (site) pode LER config, preços e upgrades ativos
drop policy if exists cfg_read   on public.site_config;
create policy cfg_read   on public.site_config for select using (true);
drop policy if exists precos_read on public.precos;
create policy precos_read on public.precos for select using (true);
drop policy if exists upg_read  on public.upgrades;
create policy upg_read  on public.upgrades for select using (true);

-- Público (site) pode CRIAR lead (captura do simulador)
drop policy if exists leads_insert_public on public.leads;
create policy leads_insert_public on public.leads for insert
  to anon with check (origem = 'site');

-- Admin autenticado: acesso total
drop policy if exists cfg_admin    on public.site_config;
create policy cfg_admin    on public.site_config for all to authenticated using (true) with check (true);
drop policy if exists precos_admin on public.precos;
create policy precos_admin on public.precos for all to authenticated using (true) with check (true);
drop policy if exists upg_admin    on public.upgrades;
create policy upg_admin    on public.upgrades for all to authenticated using (true) with check (true);
drop policy if exists leads_admin  on public.leads;
create policy leads_admin  on public.leads for all to authenticated using (true) with check (true);
drop policy if exists prop_admin   on public.propostas;
create policy prop_admin   on public.propostas for all to authenticated using (true) with check (true);
drop policy if exists ev_admin     on public.eventos;
create policy ev_admin     on public.eventos for all to authenticated using (true) with check (true);
drop policy if exists blk_admin    on public.bloqueios;
create policy blk_admin    on public.bloqueios for all to authenticated using (true) with check (true);

-- ============================================================
-- GRANTS explícitos (cobre projetos com default privileges restritos)
-- ============================================================
grant usage on schema public to anon, authenticated;
grant select on public.site_config, public.precos, public.upgrades to anon;
grant insert on public.leads to anon;
grant select, insert, update, delete on public.site_config, public.precos, public.upgrades,
  public.leads, public.propostas, public.eventos, public.bloqueios to authenticated;
grant usage, select on sequence public.precos_id_seq to authenticated;

-- ============================================================
-- RPCs públicas (proposta por token — sem expor a tabela)
-- ============================================================
create or replace function public.get_proposta(p_token uuid)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select to_jsonb(p) - 'lead_id'
  from public.propostas p
  where p.token = p_token
$$;

create or replace function public.aceitar_proposta(p_token uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.propostas
     set status = 'aceita'
   where token = p_token
     and status in ('enviada','rascunho');
  return found;
end $$;

revoke all on function public.get_proposta(uuid) from public;
revoke all on function public.aceitar_proposta(uuid) from public;
grant execute on function public.get_proposta(uuid) to anon, authenticated;
grant execute on function public.aceitar_proposta(uuid) to anon, authenticated;

-- ============================================================
-- SEED — dados iniciais (só insere se não existir)
-- ============================================================
insert into public.precos (dia, convidados, valor) values
  ('seg', 60, 134),('seg', 80, 129),('seg', 100, 119),('seg', 150, 114),
  ('sex', 60, 142),('sex', 80, 137),('sex', 100, 127),('sex', 150, 122),
  ('sab', 60, 149),('sab', 80, 144),('sab', 100, 134),('sab', 150, 129)
on conflict (dia, convidados) do nothing;

insert into public.site_config (key, value) values
  ('whatsapp',            '"5521995060184"'),
  ('telefone_exibicao',   '"(21) 99506-0184"'),
  ('email',               '"festanogalpe@gmail.com"'),
  ('instagram',           '"@festanogalpe"'),
  ('endereco',            '"Rua Yeda, 184 – Tijuca, Teresópolis/RJ"'),
  ('duracao_horas',       '4'),
  ('sinal_percent',       '10'),
  ('validade_proposta_dias', '7'),
  ('hora_extra_antecipada_percent', '15'),
  ('hora_extra_dia_percent', '20'),
  ('criancas_gratis_ate', '5'),
  ('meia_de',             '6'),
  ('meia_ate',            '9'),
  ('docinhos_por_pessoa', '5'),
  ('tolerancia_min',      '30'),
  ('max_extra_percent',   '10'),
  ('comida_verdade_preco','25'),
  ('horarios_sabado',     '["12:00","18:00"]')
on conflict (key) do nothing;

insert into public.upgrades (nome, descricao, preco, unidade, ordem)
select * from (values
  ('Ilha de pipoca',      'Pipoca fresquinha saindo na hora', null::numeric, 'fixo', 1),
  ('Algodão doce',        'Nuvens coloridas para todas as idades', null, 'fixo', 2),
  ('Carrinho de picolé',  'Refrescância direto do carrinho', null, 'fixo', 3),
  ('Creperia',            'Crepes doces e salgados na hora', null, 'fixo', 4),
  ('Drinks',              'Carta de drinks para os adultos', null, 'fixo', 5),
  ('Máquina de pelúcias', 'Exclusividade Galpê — lembrancinha viva', null, 'fixo', 6),
  ('Comida de verdade',   'Até 3 mini porções por pessoa', 25, 'por_pessoa', 7),
  ('Hora extra antecipada','15% do valor do contrato por hora', null, 'por_hora', 8)
) as v(nome, descricao, preco, unidade, ordem)
where not exists (select 1 from public.upgrades);

-- ============================================================
-- PASSOS MANUAIS OBRIGATÓRIOS (no Dashboard do Supabase):
-- 1. Authentication → Sign In / Providers →
--    DESATIVE "Allow new users to sign up"  (CRÍTICO: o painel
--    dá acesso total a qualquer usuário autenticado)
-- 2. Authentication → Passwords → ative "Leaked password protection"
-- ============================================================

-- ============================================================
-- FIM. Agora crie o usuário admin:
-- Dashboard → Authentication → Users → "Add user"
--   email:  use o e-mail do cliente (ex.: festanogalpe@gmail.com)
--   senha:  uma senha forte
--   ✓ Auto Confirm User
-- ============================================================
