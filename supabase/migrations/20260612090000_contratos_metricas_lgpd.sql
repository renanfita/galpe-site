-- ============================================================
-- Contratos com assinatura eletrônica + metas/GA4/LGPD (06/2026)
-- Fluxo: admin gera contrato a partir da proposta aceita →
-- cliente acessa contrato.html?t=TOKEN → assina eletronicamente
-- (nome + CPF + desenho) → trilha de auditoria (hash SHA-256 do
-- texto, data/hora, IP e user-agent) gravada via RPC security
-- definer. Acesso público sempre por RPC com token, nunca select.
-- Idempotente.
-- ============================================================

-- ---------- 1) Tabela de contratos ----------
create table if not exists public.contratos (
  id uuid primary key default gen_random_uuid(),
  proposta_id uuid references public.propostas(id) on delete set null,
  evento_id uuid references public.eventos(id) on delete set null,
  token uuid not null unique default gen_random_uuid(),
  numero text not null unique,
  -- contratante
  contratante_nome text not null,
  contratante_cpf text,
  contratante_endereco text,
  contratante_telefone text,
  contratante_email text,
  -- snapshot da festa (imutável após assinatura)
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
  -- documento (texto integral renderizado; o hash de aceite é dele)
  texto_contrato text not null,
  -- assinatura eletrônica + trilha de auditoria
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

-- ---------- 2) RLS: só admin acessa a tabela diretamente ----------
alter table public.contratos enable row level security;
drop policy if exists ctr_admin on public.contratos;
create policy ctr_admin on public.contratos for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.contratos to authenticated;

-- ---------- 3) RPC pública: leitura por token (whitelist, CPF mascarado) ----------
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

-- ---------- 4) RPC pública: assinatura eletrônica ----------
-- Só contratos ENVIADOS. Hash SHA-256 calculado no servidor sobre o
-- texto vigente; IP/user-agent extraídos dos headers do PostgREST.
-- search_path inclui extensions: no Supabase o pgcrypto (digest) mora lá.
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

-- ---------- 5) Novas chaves de configuração ----------
-- metas do painel, GA4 (medição só com consentimento — LGPD),
-- dados da contratada para o contrato e chave PIX de pagamento.
insert into public.site_config (key, value) values
  ('meta_festas_mes',   '8'),
  ('meta_receita_mes',  '80000'),
  ('ga4_id',            '""'),
  ('razao_social',      '""'),
  ('cnpj',              '""'),
  ('pix_chave',         '""')
on conflict (key) do nothing;
