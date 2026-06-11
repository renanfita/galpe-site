-- ============================================================
-- Meia-entrada (crianças de 6 a 9 anos) no fluxo de propostas
-- Regra de negócio confirmada: a FAIXA de preço é definida só
-- pelos convidados integrais; meias pagam 50% do valor/pessoa
-- da faixa. Adicionais "por pessoa" cobram integrais + meias.
-- ============================================================

alter table public.propostas
  add column if not exists convidados_meia int not null default 0;

alter table public.propostas drop constraint if exists prop_meia_chk;
alter table public.propostas
  add constraint prop_meia_chk check (convidados_meia >= 0);

-- get_proposta: recria a whitelist de colunas incluindo a meia
-- (grants existentes da função são preservados pelo replace)
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
