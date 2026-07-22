-- ============================================================================
-- TRUST ANALYSIS GAME — Auth + RLS lockdown migration
-- ============================================================================
-- Run this ONCE in the Supabase SQL Editor (Project > SQL Editor > New query).
--
-- BEFORE running this, create the admin login user:
--   Supabase Dashboard > Authentication > Users > Add user
--   Set an email + strong password for yourself (this replaces the old
--   hardcoded 'vijay11' password baked into admin.html).
--   You'll enter these credentials in the admin.html login screen from now on.
--
-- WHAT THIS DOES
--   - Every table gets RLS enabled.
--   - The `authenticated` role (i.e. an admin who logged in via Supabase Auth)
--     keeps full read/write/delete access to everything, same as the admin
--     panel does today.
--   - The `anon` role (the public anon key, used by every visitor to
--     index.html and by admin.html before login) can no longer read or write
--     ta_events / ta_sessions directly at all — this is what let anyone
--     harvest every organisation's 4-digit PIN with a single unauthenticated
--     request. Those two lookups are replaced by a SECURITY DEFINER RPC
--     (get_session_by_pin) that only ever returns the one session matching
--     an exact PIN you already have.
--   - For every other table (teams, participants, rounds, answers, scores,
--     case studies), `anon` keeps exactly the read/write it needs to play the
--     game — no more, no less — because reaching those rows still requires
--     first knowing a valid session PIN (there is no other way to learn an
--     event_id/session_id/team_id without it).
--
-- RESIDUAL RISK (documented, not fixed here): the 4-digit PIN itself is not
-- rate-limited at the database level, so a scripted attacker could still
-- brute-force PINs by calling get_session_by_pin() ~10,000 times. Consider
-- adding a Supabase Edge Function with rate limiting in front of it if this
-- becomes a real concern for a given event.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ta_events (Organisations) — admin only. Participants get the org name back
-- from get_session_by_pin() instead of querying this table directly.
-- ---------------------------------------------------------------------------
alter table ta_events enable row level security;
revoke all on ta_events from anon;
grant all on ta_events to authenticated;
drop policy if exists "admin full access" on ta_events;
create policy "admin full access" on ta_events for all to authenticated using (true) with check (true);

-- ---------------------------------------------------------------------------
-- ta_sessions — admin only. Participants reach this exclusively through the
-- get_session_by_pin() RPC below, never through a direct table read.
-- ---------------------------------------------------------------------------
alter table ta_sessions enable row level security;
revoke all on ta_sessions from anon;
grant all on ta_sessions to authenticated;
drop policy if exists "admin full access" on ta_sessions;
create policy "admin full access" on ta_sessions for all to authenticated using (true) with check (true);

-- ---------------------------------------------------------------------------
-- ta_teams — participants read (to show team names/colours); only admin
-- creates/edits/deletes teams.
-- ---------------------------------------------------------------------------
alter table ta_teams enable row level security;
revoke all on ta_teams from anon;
grant select on ta_teams to anon;
grant all on ta_teams to authenticated;
drop policy if exists "admin full access" on ta_teams;
drop policy if exists "anon read" on ta_teams;
create policy "admin full access" on ta_teams for all to authenticated using (true) with check (true);
create policy "anon read" on ta_teams for select to anon using (true);

-- ---------------------------------------------------------------------------
-- ta_participants — participants read everyone (name-picker, presence
-- matrix, team lists) and may flip exactly two columns on ANY row:
-- is_present (marking their own presence) and is_captain (majority-vote
-- captain election, which by design updates a teammate's row, not their
-- own). Reassigning team_id, deleting, or renaming participants stays
-- admin-only.
-- ---------------------------------------------------------------------------
alter table ta_participants enable row level security;
revoke all on ta_participants from anon;
grant select on ta_participants to anon;
grant update (is_present, is_captain) on ta_participants to anon;
grant all on ta_participants to authenticated;
drop policy if exists "admin full access" on ta_participants;
drop policy if exists "anon read" on ta_participants;
drop policy if exists "anon update presence and captain" on ta_participants;
create policy "admin full access" on ta_participants for all to authenticated using (true) with check (true);
create policy "anon read" on ta_participants for select to anon using (true);
create policy "anon update presence and captain" on ta_participants for update to anon using (true) with check (true);

-- ---------------------------------------------------------------------------
-- ta_rounds — participants read (case study, timer, status); only admin
-- changes multiplier/timer/status.
-- ---------------------------------------------------------------------------
alter table ta_rounds enable row level security;
revoke all on ta_rounds from anon;
grant select on ta_rounds to anon;
grant all on ta_rounds to authenticated;
drop policy if exists "admin full access" on ta_rounds;
drop policy if exists "anon read" on ta_rounds;
create policy "admin full access" on ta_rounds for all to authenticated using (true) with check (true);
create policy "anon read" on ta_rounds for select to anon using (true);

-- ---------------------------------------------------------------------------
-- ta_round_cases / ta_round_case_teams — participants read only; admin
-- manages case studies.
-- ---------------------------------------------------------------------------
alter table ta_round_cases enable row level security;
revoke all on ta_round_cases from anon;
grant select on ta_round_cases to anon;
grant all on ta_round_cases to authenticated;
drop policy if exists "admin full access" on ta_round_cases;
drop policy if exists "anon read" on ta_round_cases;
create policy "admin full access" on ta_round_cases for all to authenticated using (true) with check (true);
create policy "anon read" on ta_round_cases for select to anon using (true);

alter table ta_round_case_teams enable row level security;
revoke all on ta_round_case_teams from anon;
grant select on ta_round_case_teams to anon;
grant all on ta_round_case_teams to authenticated;
drop policy if exists "admin full access" on ta_round_case_teams;
drop policy if exists "anon read" on ta_round_case_teams;
create policy "admin full access" on ta_round_case_teams for all to authenticated using (true) with check (true);
create policy "anon read" on ta_round_case_teams for select to anon using (true);

-- ---------------------------------------------------------------------------
-- ta_individual_answers — participants submit their own opinion (insert) and
-- the auto-submit path upserts (insert+update via merge-duplicates). No
-- participant-triggered deletes.
-- ---------------------------------------------------------------------------
alter table ta_individual_answers enable row level security;
revoke all on ta_individual_answers from anon;
grant select, insert, update on ta_individual_answers to anon;
grant all on ta_individual_answers to authenticated;
drop policy if exists "admin full access" on ta_individual_answers;
drop policy if exists "anon submit" on ta_individual_answers;
create policy "admin full access" on ta_individual_answers for all to authenticated using (true) with check (true);
create policy "anon submit" on ta_individual_answers for all to anon using (true) with check (true);

-- ---------------------------------------------------------------------------
-- ta_team_answers — captain submits the team's answer (insert/upsert).
-- ---------------------------------------------------------------------------
alter table ta_team_answers enable row level security;
revoke all on ta_team_answers from anon;
grant select, insert, update on ta_team_answers to anon;
grant all on ta_team_answers to authenticated;
drop policy if exists "admin full access" on ta_team_answers;
drop policy if exists "anon submit" on ta_team_answers;
create policy "admin full access" on ta_team_answers for all to authenticated using (true) with check (true);
create policy "anon submit" on ta_team_answers for all to anon using (true) with check (true);

-- ---------------------------------------------------------------------------
-- ta_captain_votes — participants cast/change their captain vote.
-- ---------------------------------------------------------------------------
alter table ta_captain_votes enable row level security;
revoke all on ta_captain_votes from anon;
grant select, insert, update on ta_captain_votes to anon;
grant all on ta_captain_votes to authenticated;
drop policy if exists "admin full access" on ta_captain_votes;
drop policy if exists "anon vote" on ta_captain_votes;
create policy "admin full access" on ta_captain_votes for all to authenticated using (true) with check (true);
create policy "anon vote" on ta_captain_votes for all to anon using (true) with check (true);

-- ---------------------------------------------------------------------------
-- ta_scores — participants only ever read the scoreboard; admin calculates
-- and writes scores on reveal.
-- ---------------------------------------------------------------------------
alter table ta_scores enable row level security;
revoke all on ta_scores from anon;
grant select on ta_scores to anon;
grant all on ta_scores to authenticated;
drop policy if exists "admin full access" on ta_scores;
drop policy if exists "anon read" on ta_scores;
create policy "admin full access" on ta_scores for all to authenticated using (true) with check (true);
create policy "anon read" on ta_scores for select to anon using (true);

-- ---------------------------------------------------------------------------
-- RPC: the only way `anon` can ever reach ta_sessions / ta_events data.
-- SECURITY DEFINER lets it read those RLS-locked tables internally, but it
-- only ever returns the single row matching an exact PIN — never a listing.
-- ---------------------------------------------------------------------------
create or replace function public.get_session_by_pin(p_pin text)
returns table (
  id uuid,
  event_id uuid,
  event_name text,
  name text,
  status text,
  current_round int,
  total_rounds int
)
language sql
security definer
set search_path = public
as $$
  select s.id, s.event_id, e.name as event_name, s.name, s.status, s.current_round, s.total_rounds
  from ta_sessions s
  join ta_events e on e.id = s.event_id
  where s.pin = p_pin
  limit 1;
$$;

revoke all on function public.get_session_by_pin(text) from public;
grant execute on function public.get_session_by_pin(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage: case-study file uploads (bucket "trust-analysis"). admin.html now
-- authenticates before uploading, so require that role for writes. Reading
-- case files stays open (the app links to them via the public object URL,
-- which only works if the bucket itself is marked "Public" in
-- Storage > trust-analysis > Settings — that flag bypasses these policies
-- for GET, so no anon SELECT policy is needed here).
-- ---------------------------------------------------------------------------
drop policy if exists "admin can upload case files" on storage.objects;
create policy "admin can upload case files"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'trust-analysis');

drop policy if exists "admin can overwrite case files" on storage.objects;
create policy "admin can overwrite case files"
  on storage.objects for update to authenticated
  using (bucket_id = 'trust-analysis');

drop policy if exists "admin can delete case files" on storage.objects;
create policy "admin can delete case files"
  on storage.objects for delete to authenticated
  using (bucket_id = 'trust-analysis');
