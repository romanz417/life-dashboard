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
