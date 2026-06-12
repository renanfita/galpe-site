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
  convidados_meia int not null default 0,
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
-- SEGURANÇA REFORÇADA (hardening — auditoria 06/2026)
-- Sobrepõe políticas/funções acima. Idempotente.
-- ============================================================

-- ---------- H1) Constraints de tamanho/sanidade (anti-abuso) ----------
alter table public.leads drop constraint if exists leads_nome_len;
alter table public.leads add constraint leads_nome_len check (nome is null or char_length(nome) <= 120);
alter table public.leads drop constraint if exists leads_tel_len;
alter table public.leads add constraint leads_tel_len check (telefone is null or char_length(telefone) <= 30);
alter table public.leads drop constraint if exists leads_obs_len;
alter table public.leads add constraint leads_obs_len check (observacoes is null or char_length(observacoes) <= 1000);
alter table public.leads drop constraint if exists leads_conv_range;
alter table public.leads add constraint leads_conv_range check (convidados is null or convidados between 1 and 1000);
alter table public.leads drop constraint if exists leads_dia_chk;
alter table public.leads add constraint leads_dia_chk check (dia_tipo is null or dia_tipo in ('seg','sex','sab'));
alter table public.propostas drop constraint if exists prop_desc_chk;
alter table public.propostas add constraint prop_desc_chk check (desconto >= 0);
alter table public.propostas drop constraint if exists prop_idade_chk;
alter table public.propostas add constraint prop_idade_chk check (idade is null or idade between 0 and 130);
alter table public.propostas add column if not exists convidados_meia int not null default 0;
alter table public.propostas drop constraint if exists prop_meia_chk;
alter table public.propostas add constraint prop_meia_chk check (convidados_meia >= 0);

-- ---------- H2) Insert público de leads: só colunas seguras + status travado ----------
drop policy if exists leads_insert_public on public.leads;
create policy leads_insert_public on public.leads for insert
  to anon with check (origem = 'site' and status = 'novo');
revoke insert on public.leads from anon;
grant insert (nome, telefone, origem, data_interesse, convidados, dia_tipo, observacoes)
  on public.leads to anon;

-- ---------- H3) Throttle global de leads (anti-spam/flood) ----------
create or replace function public.leads_throttle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.leads where created_at > now() - interval '1 hour') >= 60 then
    raise exception 'Muitos pedidos no momento. Tente novamente mais tarde.';
  end if;
  return new;
end $$;
drop trigger if exists trg_leads_throttle on public.leads;
create trigger trg_leads_throttle before insert on public.leads
  for each row execute function public.leads_throttle();

-- ---------- H4) Admins explícitos (não basta estar autenticado) ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select to authenticated using (user_id = auth.uid());
grant select on public.admins to authenticated;
-- Registra como admin todos os usuários já criados (rode de novo após criar o usuário admin!)
insert into public.admins (user_id) select id from auth.users on conflict do nothing;

-- Políticas de admin agora exigem is_admin()
drop policy if exists cfg_admin    on public.site_config;
create policy cfg_admin    on public.site_config for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists precos_admin on public.precos;
create policy precos_admin on public.precos for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists upg_admin    on public.upgrades;
create policy upg_admin    on public.upgrades for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists leads_admin  on public.leads;
create policy leads_admin  on public.leads for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists prop_admin   on public.propostas;
create policy prop_admin   on public.propostas for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists ev_admin     on public.eventos;
create policy ev_admin     on public.eventos for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists blk_admin    on public.bloqueios;
create policy blk_admin    on public.bloqueios for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- H5) RPCs endurecidas ----------
-- get_proposta: whitelist de colunas (nunca vaza campos internos futuros)
create or replace function public.get_proposta(p_token uuid)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'nome_cliente', p.nome_cliente,
    'aniversariante', p.aniversariante,
    'idade', p.idade,
    'tema', p.tema,
    'data_evento', p.data_evento,
    'horario', p.horario,
    'convidados', p.convidados,
    'convidados_meia', p.convidados_meia,
    'dia_tipo', p.dia_tipo,
    'valor_pessoa', p.valor_pessoa,
    'upgrades', p.upgrades,
    'desconto', p.desconto,
    'observacoes', p.observacoes,
    'validade', p.validade,
    'status', p.status
  )
  from public.propostas p
  where p.token = p_token
$$;

-- aceitar_proposta: só propostas ENVIADAS e dentro da validade
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
     and status = 'enviada'
     and (validade is null or validade >= current_date);
  return found;
end $$;

revoke all on function public.get_proposta(uuid) from public;
revoke all on function public.aceitar_proposta(uuid) from public;
grant execute on function public.get_proposta(uuid) to anon, authenticated;
grant execute on function public.aceitar_proposta(uuid) to anon, authenticated;

-- ============================================================
-- CONTRATOS com assinatura eletrônica + metas/GA4/LGPD (06/2026)
-- (espelho da migração 20260612090000_contratos_metricas_lgpd)
-- ============================================================

create table if not exists public.contratos (
  id uuid primary key default gen_random_uuid(),
  proposta_id uuid references public.propostas(id) on delete set null,
  evento_id uuid references public.eventos(id) on delete set null,
  token uuid not null unique default gen_random_uuid(),
  numero text not null unique,
  contratante_nome text not null,
  contratante_cpf text,
  contratante_endereco text,
  contratante_telefone text,
  contratante_email text,
  aniversariante text,
  tema text,
  data_evento date not null,
  horario text,
  convidados int not null check (convidados > 0),
  convidados_meia int not null default 0 check (convidados_meia >= 0),
  valor_total numeric(10,2) not null check (valor_total >= 0),
  sinal_valor numeric(10,2) not null default 0 check (sinal_valor >= 0),
  upgrades jsonb not null default '[]'::jsonb,
  observacoes text,
  texto_contrato text not null,
  status text not null default 'rascunho'
    check (status in ('rascunho','enviado','assinado','cancelado')),
  assinado_em timestamptz,
  assinante_nome text,
  assinante_cpf text,
  assinatura_img text,
  aceite_hash text,
  aceite_ip text,
  aceite_user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists contratos_data_idx on public.contratos (data_evento);

drop trigger if exists trg_touch_contratos on public.contratos;
create trigger trg_touch_contratos before update on public.contratos
  for each row execute function public.touch_updated_at();

alter table public.contratos enable row level security;
drop policy if exists ctr_admin on public.contratos;
create policy ctr_admin on public.contratos for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.contratos to authenticated;

-- Leitura pública por token (whitelist de colunas, CPF mascarado)
create or replace function public.get_contrato(p_token uuid)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'numero', c.numero,
    'contratante_nome', c.contratante_nome,
    'aniversariante', c.aniversariante,
    'tema', c.tema,
    'data_evento', c.data_evento,
    'horario', c.horario,
    'convidados', c.convidados,
    'convidados_meia', c.convidados_meia,
    'valor_total', c.valor_total,
    'sinal_valor', c.sinal_valor,
    'texto_contrato', c.texto_contrato,
    'status', c.status,
    'assinado_em', c.assinado_em,
    'assinante_nome', c.assinante_nome,
    'assinante_cpf_mask', case when c.assinante_cpf is null then null
      else '***.' || substr(c.assinante_cpf, 4, 3) || '.' || substr(c.assinante_cpf, 7, 3) || '-**' end,
    'assinatura_img', c.assinatura_img,
    'aceite_hash', c.aceite_hash
  )
  from public.contratos c
  where c.token = p_token
$$;

-- Assinatura eletrônica: só contratos ENVIADOS; hash SHA-256 do texto
-- vigente calculado no servidor; IP/user-agent dos headers do PostgREST.
create or replace function public.assinar_contrato(
  p_token uuid, p_nome text, p_cpf text, p_assinatura text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  c public.contratos%rowtype;
  v_cpf text;
  v_ip text := '';
  v_ua text := '';
  v_hash text;
begin
  if p_nome is null or length(btrim(p_nome)) < 5 or length(p_nome) > 120 then
    return jsonb_build_object('ok', false, 'erro', 'nome');
  end if;
  v_cpf := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
  if length(v_cpf) <> 11 then
    return jsonb_build_object('ok', false, 'erro', 'cpf');
  end if;
  if p_assinatura is null
     or p_assinatura !~ '^data:image/(png|jpeg);base64,[A-Za-z0-9+/=]+$'
     or length(p_assinatura) > 200000 then
    return jsonb_build_object('ok', false, 'erro', 'assinatura');
  end if;

  select * into c from public.contratos
   where token = p_token and status = 'enviado'
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'indisponivel');
  end if;

  begin
    v_ip := coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for', '');
    v_ua := coalesce(current_setting('request.headers', true)::json->>'user-agent', '');
  exception when others then
    v_ip := ''; v_ua := '';
  end;

  v_hash := encode(digest(c.texto_contrato, 'sha256'), 'hex');

  update public.contratos set
    status = 'assinado',
    assinado_em = now(),
    assinante_nome = btrim(p_nome),
    assinante_cpf = v_cpf,
    assinatura_img = p_assinatura,
    aceite_hash = v_hash,
    aceite_ip = left(v_ip, 100),
    aceite_user_agent = left(v_ua, 300)
  where id = c.id;

  return jsonb_build_object('ok', true, 'assinado_em', now(), 'hash', v_hash);
end $$;

revoke all on function public.get_contrato(uuid) from public;
revoke all on function public.assinar_contrato(uuid, text, text, text) from public;
grant execute on function public.get_contrato(uuid) to anon, authenticated;
grant execute on function public.assinar_contrato(uuid, text, text, text) to anon, authenticated;

-- Novas chaves de configuração (metas, GA4, contratada, PIX)
insert into public.site_config (key, value) values
  ('meta_festas_mes',   '8'),
  ('meta_receita_mes',  '80000'),
  ('ga4_id',            '""'),
  ('razao_social',      '""'),
  ('cnpj',              '""'),
  ('pix_chave',         '""')
on conflict (key) do nothing;

-- ============================================================
-- PERFORMANCE — lints do advisor (= migração 20260612150000)
-- auth.uid()/is_admin() como initplan; nas tabelas de leitura
-- pública a policy de admin cobre só escrita (o SELECT é a *_read).
-- ============================================================
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists cfg_admin     on public.site_config;
drop policy if exists cfg_admin_ins on public.site_config;
create policy cfg_admin_ins on public.site_config for insert to authenticated
  with check ((select public.is_admin()));
drop policy if exists cfg_admin_upd on public.site_config;
create policy cfg_admin_upd on public.site_config for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists cfg_admin_del on public.site_config;
create policy cfg_admin_del on public.site_config for delete to authenticated
  using ((select public.is_admin()));

drop policy if exists precos_admin     on public.precos;
drop policy if exists precos_admin_ins on public.precos;
create policy precos_admin_ins on public.precos for insert to authenticated
  with check ((select public.is_admin()));
drop policy if exists precos_admin_upd on public.precos;
create policy precos_admin_upd on public.precos for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists precos_admin_del on public.precos;
create policy precos_admin_del on public.precos for delete to authenticated
  using ((select public.is_admin()));

drop policy if exists upg_admin     on public.upgrades;
drop policy if exists upg_admin_ins on public.upgrades;
create policy upg_admin_ins on public.upgrades for insert to authenticated
  with check ((select public.is_admin()));
drop policy if exists upg_admin_upd on public.upgrades;
create policy upg_admin_upd on public.upgrades for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists upg_admin_del on public.upgrades;
create policy upg_admin_del on public.upgrades for delete to authenticated
  using ((select public.is_admin()));

drop policy if exists leads_admin on public.leads;
create policy leads_admin on public.leads for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists prop_admin on public.propostas;
create policy prop_admin on public.propostas for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists ev_admin on public.eventos;
create policy ev_admin on public.eventos for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists blk_admin on public.bloqueios;
create policy blk_admin on public.bloqueios for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists ctr_admin on public.contratos;
create policy ctr_admin on public.contratos for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

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
