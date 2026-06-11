-- ============================================================
-- SEGURANÇA REFORÇADA (hardening — auditoria 06/2026)
-- Sobrepõe políticas/funções da migração inicial. Idempotente.
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
-- Registra como admin todos os usuários já criados.
-- (Se criar um novo usuário admin no futuro, insira-o em public.admins.)
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
