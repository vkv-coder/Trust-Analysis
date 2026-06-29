-- TRUST ANALYSIS GAME — Supabase Schema
-- Run this in Supabase SQL Editor

-- 1. SESSIONS TABLE
create table if not exists ta_sessions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  pin text not null,
  status text default 'setup', -- setup | registration | breakout | scoring | complete
  current_round int default 0,
  total_rounds int default 10,
  created_at timestamp default now()
);

-- 2. TEAMS TABLE
create table if not exists ta_teams (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references ta_sessions(id) on delete cascade,
  name text not null,
  color text default '#3B82F6',
  created_at timestamp default now()
);

-- 3. PARTICIPANTS TABLE
create table if not exists ta_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references ta_sessions(id) on delete cascade,
  team_id uuid references ta_teams(id) on delete cascade,
  name text not null,
  is_captain boolean default false,
  created_at timestamp default now()
);

-- 4. ROUNDS TABLE
create table if not exists ta_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references ta_sessions(id) on delete cascade,
  round_number int not null,
  multiplier int default 1,
  case_study text,
  status text default 'pending', -- pending | registration_open | breakout_open | revealed
  timer_seconds int default 300,
  timer_started_at timestamp,
  created_at timestamp default now()
);

-- 5. INDIVIDUAL ANSWERS TABLE (Phase 1 - opinion only, no score)
create table if not exists ta_individual_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references ta_sessions(id) on delete cascade,
  round_id uuid references ta_rounds(id) on delete cascade,
  participant_id uuid references ta_participants(id) on delete cascade,
  answer text not null, -- 'H' or 'L'
  submitted_at timestamp default now()
);

-- 6. TEAM ANSWERS TABLE (Phase 2 - captain submits, earns points)
create table if not exists ta_team_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references ta_sessions(id) on delete cascade,
  round_id uuid references ta_rounds(id) on delete cascade,
  team_id uuid references ta_teams(id) on delete cascade,
  answer text not null, -- 'H' or 'L'
  submitted_by uuid references ta_participants(id),
  submitted_at timestamp default now(),
  unique(round_id, team_id)
);

-- 7. SCORES TABLE (auto-calculated after each round)
create table if not exists ta_scores (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references ta_sessions(id) on delete cascade,
  round_id uuid references ta_rounds(id) on delete cascade,
  team_id uuid references ta_teams(id) on delete cascade,
  round_points int default 0,
  cumulative_points int default 0,
  calculated_at timestamp default now(),
  unique(round_id, team_id)
);

-- Disable RLS for simplicity (PIN-gated at app level)
alter table ta_sessions disable row level security;
alter table ta_teams disable row level security;
alter table ta_participants disable row level security;
alter table ta_rounds disable row level security;
alter table ta_individual_answers disable row level security;
alter table ta_team_answers disable row level security;
alter table ta_scores disable row level security;
