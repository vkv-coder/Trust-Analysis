-- ============================================================================
-- TRUST ANALYSIS GAME — drop stray "anon_all" policies
-- ============================================================================
-- Already applied directly against the live database 2026-10-01.
-- Committed here purely as a record of what changed, matching this repo's
-- convention (see supabase_auth_rls_migration.sql) — safe to re-run, no-op
-- if the policies are already gone.
--
-- CONTEXT
--   supabase_auth_rls_migration.sql already locked this app down correctly:
--   ta_events/ta_sessions have zero anon grants (reachable only through the
--   get_session_by_pin RPC), and every other table has narrow, sometimes
--   column-level, anon grants matching exactly what the game needs.
--
--   A monthly RLS audit on 2026-10-01 found that 8 of those 10 tables also
--   carried a leftover "anon_all" policy (ALL commands, qual=true) layered
--   on top of the correct narrow ones. Table GRANTs were already correct, so
--   this was inert in practice (confirmed live via curl both before and
--   after the drop — same FK-constraint errors, same 42501s, nothing
--   changed behaviorally) — but it was a landmine: anyone who later loosened
--   a GRANT without realizing this policy existed would reopen full access
--   instantly. Likely origin: a Supabase dashboard "quick-enable RLS"
--   convenience click, not anything in this repo's own migrations.
-- ============================================================================

drop policy if exists anon_all on public.ta_events;
drop policy if exists anon_all on public.ta_sessions;
drop policy if exists anon_all on public.ta_individual_answers;
drop policy if exists anon_all on public.ta_team_answers;
drop policy if exists anon_all on public.ta_participants;
drop policy if exists anon_all on public.ta_rounds;
drop policy if exists anon_all on public.ta_scores;
drop policy if exists anon_all on public.ta_teams;
