-- ============================================================
-- PERFORMANCE — lints do Supabase advisor (12/06/2026)
-- 0003 auth_rls_initplan: auth.uid()/is_admin() embrulhados em
--   (select …) viram InitPlan — avaliados 1x por consulta, e não
--   linha a linha (importa em leads/propostas, que crescem).
-- 0006 multiple_permissive_policies: nas tabelas de leitura
--   pública (site_config/precos/upgrades) a policy de admin passa
--   a cobrir só escrita — o SELECT já vem da *_read, então o
--   usuário autenticado avalia uma única policy por ação.
-- Idempotente.
-- ============================================================

-- ---------- P1) admins: initplan no auth.uid() ----------
drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------- P2) site_config / precos / upgrades: admin só escreve ----------
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

-- ---------- P3) demais tabelas: mantêm ALL, com initplan no is_admin() ----------
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
