-- SkillWiz: Supabase schema for accounts, login records and leads.
-- Run this whole file once in Supabase: SQL Editor > New query > paste > Run.
-- Safe to re-run: every object is created only if it does not exist.

-- 1. PROFILES: one row per registered user (created automatically on sign-up) ---------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  full_name    text,
  role         text not null default 'student'
               check (role in ('student','faculty','tpo','leadership','recruiter')),
  org          text,
  phone        text,
  is_admin     boolean not null default false,
  consented_at timestamptz,
  created_at   timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- helper: is the current user an admin? (security definer so it can read profiles without recursion)
create or replace function public.is_admin() returns boolean
language sql security definer set search_path = public stable as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

drop policy if exists "profiles: read own or admin" on public.profiles;
create policy "profiles: read own or admin" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- users may edit only these columns (nobody can make themselves admin or change their role)
revoke update on public.profiles from authenticated;
grant  update (full_name, org, phone) on public.profiles to authenticated;

-- create the profile when a user signs up (role limited to the allowed list; admin is never self-assigned)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text := coalesce(new.raw_user_meta_data->>'role', 'student');
begin
  if r not in ('student','faculty','tpo','leadership','recruiter') then r := 'student'; end if;
  insert into public.profiles (id, email, full_name, role, org, phone, consented_at)
  values (new.id, new.email,
          new.raw_user_meta_data->>'full_name', r,
          new.raw_user_meta_data->>'org', new.raw_user_meta_data->>'phone',
          case when (new.raw_user_meta_data->>'consent') = 'true' then now() end)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. LOGIN EVENTS: one row each time someone signs in or signs up -----------------------------
create table if not exists public.login_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  email      text default (auth.jwt() ->> 'email'),
  event      text not null check (event in ('sign_in','sign_up','sign_in_link')),
  role       text,
  user_agent text,
  page       text,
  created_at timestamptz not null default now()
);
alter table public.login_events enable row level security;

drop policy if exists "login_events: insert own" on public.login_events;
create policy "login_events: insert own" on public.login_events
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "login_events: read own or admin" on public.login_events;
create policy "login_events: read own or admin" on public.login_events
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

create index if not exists login_events_user_idx on public.login_events (user_id, created_at desc);

-- 3. LEADS: every website form (proposal builder, contact, newsletter, polls, ...) -----------
create table if not exists public.leads (
  id         bigint generated always as identity primary key,
  source     text not null,
  data       jsonb not null default '{}'::jsonb,
  page       text,
  user_id    uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.leads enable row level security;

-- visitors can add a lead but can never read, change or delete any
drop policy if exists "leads: anyone can submit" on public.leads;
create policy "leads: anyone can submit" on public.leads
  for insert to anon, authenticated
  with check (length(source) <= 60 and pg_column_size(data) < 20000);

drop policy if exists "leads: admin read" on public.leads;
create policy "leads: admin read" on public.leads
  for select to authenticated using (public.is_admin());

create index if not exists leads_source_idx on public.leads (source, created_at desc);

-- 4. ADMIN OVERVIEW: who the users are, when they last logged in, how many times -------------
create or replace function public.admin_user_overview()
returns table (id uuid, email text, full_name text, role text, org text, phone text,
               signed_up timestamptz, last_sign_in timestamptz, sign_in_count bigint)
language sql security definer set search_path = public, auth as $$
  select p.id, p.email, p.full_name, p.role, p.org, p.phone, p.created_at, u.last_sign_in_at,
         (select count(*) from public.login_events e where e.user_id = p.id and e.event <> 'sign_up')
  from public.profiles p join auth.users u on u.id = p.id
  where public.is_admin()
  order by u.last_sign_in_at desc nulls last
$$;
revoke all on function public.admin_user_overview() from public, anon;
grant execute on function public.admin_user_overview() to authenticated;

-- 5. MAKE YOURSELF THE FIRST ADMIN (after you have created your own account on the site) -----
-- Replace the email, then run this line on its own:
-- update public.profiles set is_admin = true where email = 'you@yourcompany.com';

-- 6. HANDY QUERIES (run in the SQL Editor, which bypasses the policies) -----------------------
-- select * from public.admin_user_overview();                         -- all users + last login
-- select * from public.login_events order by created_at desc limit 100; -- recent logins
-- select source, count(*) from public.leads group by 1 order by 2 desc; -- leads by form
-- select * from public.leads where source = 'proposal-builder' order by created_at desc;
