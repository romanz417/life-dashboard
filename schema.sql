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

-- goal type: 'income', 'debt' or 'general'
alter table goals add column if not exists kind text not null default 'general';

-- Debt tracker (kind = 'debt': who you owe) and financial goals (kind = 'fund': what you are saving for)
create table if not exists targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete cascade,
  kind text not null check (kind in ('debt', 'fund')),
  name text not null,
  amount numeric not null check (amount > 0),
  paid_before numeric not null default 0 check (paid_before >= 0),
  deadline date,
  note text,
  position int default 0,
  created_at timestamptz default now()
);
create index if not exists targets_area_idx on targets(area_id);
-- date a financial goal was ticked off as achieved
alter table targets add column if not exists achieved_at date;
-- emergency fund + fuller debt details
alter table targets add column if not exists role text;            -- 'emergency' for the emergency fund
alter table targets add column if not exists essentials numeric;   -- monthly essential costs
alter table targets add column if not exists interest_rate numeric check (interest_rate is null or interest_rate >= 0);
alter table targets add column if not exists rate_period text default 'year' check (rate_period in ('month', 'year'));
alter table targets add column if not exists min_payment numeric check (min_payment is null or min_payment >= 0);
alter table targets add column if not exists due_day int check (due_day is null or (due_day between 1 and 31));

-- Monthly spending limits per expense category
create table if not exists budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  category text not null,
  amount numeric not null check (amount > 0),
  essential boolean not null default false,
  created_at timestamptz default now(),
  unique (user_id, category)
);
alter table budgets enable row level security;
create policy "own budgets" on budgets for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- How each month's income is split
create table if not exists plan_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  name text not null,
  percent numeric not null check (percent > 0 and percent <= 100),
  link text not null default 'none' check (link in ('debt', 'emergency', 'goals', 'living', 'none')),
  position int default 0,
  created_at timestamptz default now()
);
alter table plan_items enable row level security;
create policy "own plan items" on plan_items for all using (user_id = auth.uid()) with check (user_id = auth.uid());
alter table targets enable row level security;
create policy "own targets" on targets for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- payments / deposits against a debt or financial goal
alter table goal_entries add column if not exists target_id uuid references targets(id) on delete set null;
create index if not exists goal_entries_target_idx on goal_entries(target_id);

-- Daily expense log
create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete set null,
  amount numeric not null check (amount > 0),
  category text not null,
  note text,
  day date not null default current_date,
  created_at timestamptz default now()
);
create index if not exists expenses_user_day_idx on expenses(user_id, day);
alter table expenses enable row level security;
create policy "own expenses" on expenses for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Your own cover photo per life area (files live in the public "covers" storage bucket, one folder per user)
alter table areas add column if not exists photo_url text;

-- Spiritual Life: morning / evening sessions, spoken affirmations, journey stages and daily peace & purpose ratings
create table if not exists spirit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete cascade,
  day date not null default current_date,
  kind text not null check (kind in ('morning', 'evening', 'affirm', 'journey', 'reflect')),
  minutes numeric check (minutes is null or minutes >= 0),
  short boolean not null default false,
  step int,                                                   -- journey stage number (keeps counting past 12)
  note text,                                                  -- journey reflection
  peace int check (peace is null or peace between 1 and 5),
  purpose int check (purpose is null or purpose between 1 and 5),
  created_at timestamptz default now(),
  unique (user_id, day, kind)
);
create index if not exists spirit_logs_user_day_idx on spirit_logs(user_id, day);
alter table spirit_logs enable row level security;
create policy "own spirit logs" on spirit_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
