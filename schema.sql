-- Life Dashboard schema for Supabase. Paste into SQL Editor and run once.

create table if not exists areas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  name text not null,
  icon text,
  active boolean default true,
  score int,
  notes text,
  position int default 0,
  created_at timestamptz default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete cascade,
  title text not null,
  created_at timestamptz default now()
);

create table if not exists checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  task_id uuid references tasks(id) on delete cascade,
  day date not null,
  unique (task_id, day)
);

alter table areas enable row level security;
alter table tasks enable row level security;
alter table checkins enable row level security;

create policy "own areas" on areas for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own tasks" on tasks for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own checkins" on checkins for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Monthly goals (e.g. income, debt payoff) and the entries logged against them
create table if not exists goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete cascade,
  title text not null,
  description text,
  target numeric not null check (target > 0),
  unit text default 'UGX',
  period text not null default 'monthly',
  entry_label text default 'Log progress',
  source_label text default 'Source',
  position int default 0,
  created_at timestamptz default now()
);

create table if not exists goal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  goal_id uuid references goals(id) on delete cascade,
  amount numeric not null check (amount > 0),
  source text,
  note text,
  day date not null default current_date,
  created_at timestamptz default now()
);

create index if not exists goals_area_idx on goals(area_id);
create index if not exists goal_entries_goal_day_idx on goal_entries(goal_id, day);

alter table goals enable row level security;
alter table goal_entries enable row level security;

create policy "own goals" on goals for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own goal entries" on goal_entries for all using (user_id = auth.uid()) with check (user_id = auth.uid());
