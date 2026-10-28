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
  kind text not null check (kind in ('morning', 'evening', 'affirm', 'journey', 'reflect', 'program')),
  minutes numeric check (minutes is null or minutes >= 0),
  short boolean not null default false,
  step int,                                                   -- journey stage number (keeps counting past 12)
  note text,                                                  -- journey reflection
  peace int check (peace is null or peace between 1 and 5),
  purpose int check (purpose is null or purpose between 1 and 5),
  data jsonb,                                                 -- 'program' rows: {read, t:[task indexes done]}; day = that program day's date
  created_at timestamptz default now(),
  unique (user_id, day, kind)
);
create index if not exists spirit_logs_user_day_idx on spirit_logs(user_id, day);
alter table spirit_logs enable row level security;
create policy "own spirit logs" on spirit_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Spiritual Life: intuition log (kind 'hunch') and wish list (kind 'wish') for the 60-day Florence Scovel Shinn program
create table if not exists spirit_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete cascade,
  kind text not null check (kind in ('hunch', 'wish')),
  text text not null,
  day date not null default current_date,
  followed boolean not null default false,
  outcome text,
  manifested_at date,
  created_at timestamptz default now()
);
create index if not exists spirit_items_user_idx on spirit_items(user_id, kind, day);
alter table spirit_items enable row level security;
create policy "own spirit items" on spirit_items for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Work & Career > Trading: journal (mode live / demo / backtest, result in R), desk settings and the daily pre-trade checklist
create table if not exists trades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  area_id uuid references areas(id) on delete set null,
  day date not null default current_date,
  instrument text not null,
  strategy text not null,
  session text,
  direction text check (direction is null or direction in ('buy', 'sell')),
  mode text not null default 'live' check (mode in ('live', 'demo', 'backtest')),
  r numeric not null,                                         -- result in R (multiples of the amount risked)
  pnl numeric,                                                -- money result
  followed boolean not null default true,                     -- followed every rule of the playbook
  emotion text,
  note text,
  created_at timestamptz default now()
);
create index if not exists trades_user_day_idx on trades(user_id, day);
alter table trades enable row level security;
create policy "own trades" on trades for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table if not exists trading_settings (
  user_id uuid primary key references auth.users(id) default auth.uid(),
  start_balance numeric not null default 500 check (start_balance >= 0),
  currency text not null default 'USD',
  risk_pct numeric not null default 1 check (risk_pct > 0 and risk_pct <= 10),
  max_trades int not null default 2 check (max_trades between 1 and 20),
  max_losses int not null default 2 check (max_losses between 1 and 20),
  playbook text,
  updated_at timestamptz default now()
);
alter table trading_settings enable row level security;
create policy "own trading settings" on trading_settings for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table if not exists trade_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  day date not null default current_date,
  items jsonb not null default '[]'::jsonb,                  -- indexes of the checklist items ticked that day
  created_at timestamptz default now(),
  unique (user_id, day)
);
alter table trade_checks enable row level security;
create policy "own trade checks" on trade_checks for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Trading > News desk: one market brief per day, written by the scheduled research task, readable by signed-in users.
-- data = { summary, risk ('low'|'medium'|'high'), events:[{time (EAT), ccy, event, impact, affects:[]}],
--          assets:[{asset, bias ('bullish'|'bearish'|'neutral'|'wait'), confidence, news:[{title, source, url}], impact, action, levels}],
--          quant_note, watch:[] }
create table if not exists market_briefs (
  id uuid primary key default gen_random_uuid(),
  day date not null,
  slot text not null default 'morning',
  data jsonb not null,
  created_at timestamptz default now(),
  unique (day, slot)
);
alter table market_briefs enable row level security;
create policy "signed-in users read briefs" on market_briefs for select to authenticated using (true);
-- forex pairs (and anything else) each person wants covered in the brief
alter table trading_settings add column if not exists watch text[] not null default '{EUR/USD,GBP/USD,USD/JPY}';

-- Trading: mistake tags and chart screenshots on each trade (screenshots live in the "covers" bucket under <user id>/trades/)
alter table trades add column if not exists mistakes text[] not null default '{}';
alter table trades add column if not exists shots text[] not null default '{}';
-- Trading: drawdown limits (in R) and the losing-streak rule (halve risk after N losses in a row)
alter table trading_settings add column if not exists weekly_loss_r numeric not null default 4 check (weekly_loss_r > 0);
alter table trading_settings add column if not exists monthly_loss_r numeric not null default 8 check (monthly_loss_r > 0);
alter table trading_settings add column if not exists halve_after int not null default 3 check (halve_after between 2 and 10);
-- Trading: weekly review (one per week, week starts Monday)
create table if not exists trade_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  week_start date not null,
  went_well text,
  to_improve text,
  rule text,
  discipline int check (discipline is null or discipline between 1 and 10),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, week_start)
);
alter table trade_reviews enable row level security;
create policy "own trade reviews" on trade_reviews for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Trading > Daily motivation: shared library of short videos from trading legends (seeded and maintained by Claude), and each person's watch log
create table if not exists trade_videos (
  id uuid primary key default gen_random_uuid(),
  video_id text not null unique,          -- YouTube id; every entry checked as embeddable
  person text not null,
  title text not null,
  topic text not null check (topic in ('Psychology', 'Discipline', 'Risk', 'Wisdom')),
  seconds int not null,
  channel text,
  note text,                              -- "watch for" prompt
  active boolean not null default true,
  created_at timestamptz default now()
);
alter table trade_videos enable row level security;
create policy "signed-in users read videos" on trade_videos for select to authenticated using (true);
create table if not exists video_watch (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) default auth.uid(),
  video_id text not null,
  day date not null default current_date,
  takeaway text,
  created_at timestamptz default now(),
  unique (user_id, video_id)
);
alter table video_watch enable row level security;
create policy "own video watch log" on video_watch for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
