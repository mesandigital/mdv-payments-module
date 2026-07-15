-- SwapLibro moderation and dispute setup
-- Run after catalog/offers/profile setup. Run before notifications.sql if moderation notifications are added later.

create extension if not exists pgcrypto;

create or replace function public.is_swaplibro_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and (
        p.metadata->>'role' = 'admin'
        or p.metadata->>'isAdmin' = 'true'
        or p.metadata->>'admin' = 'true'
      )
  );
$$;

create table if not exists public.moderation_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('item', 'profile', 'offer', 'review')),
  target_id uuid not null,
  reason text not null check (length(trim(reason)) > 0),
  details text,
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  assigned_admin_id uuid references auth.users(id) on delete set null,
  resolution text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.swap_disputes (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers(id) on delete cascade,
  item_id uuid references public.items(id) on delete set null,
  opened_by uuid not null references auth.users(id) on delete cascade,
  against_user_id uuid references auth.users(id) on delete set null,
  reason text not null check (
    reason in ('no_show', 'condition_mismatch', 'handoff_issue', 'unsafe_behavior', 'other')
  ),
  details text,
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  assigned_admin_id uuid references auth.users(id) on delete set null,
  resolution text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users(id) on delete cascade,
  action_type text not null,
  target_type text not null,
  target_id uuid not null,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists moderation_reports_status_created_idx
on public.moderation_reports (status, created_at desc);

create index if not exists moderation_reports_reporter_created_idx
on public.moderation_reports (reporter_id, created_at desc);

create index if not exists moderation_reports_target_idx
on public.moderation_reports (target_type, target_id);

create index if not exists swap_disputes_status_created_idx
on public.swap_disputes (status, created_at desc);

create index if not exists swap_disputes_offer_idx
on public.swap_disputes (offer_id);

create index if not exists swap_disputes_opened_by_idx
on public.swap_disputes (opened_by, created_at desc);

create index if not exists admin_actions_admin_created_idx
on public.admin_actions (admin_id, created_at desc);

drop trigger if exists moderation_reports_set_updated_at on public.moderation_reports;
create trigger moderation_reports_set_updated_at
before update on public.moderation_reports
for each row
execute function public.set_updated_at();

drop trigger if exists swap_disputes_set_updated_at on public.swap_disputes;
create trigger swap_disputes_set_updated_at
before update on public.swap_disputes
for each row
execute function public.set_updated_at();

alter table public.moderation_reports enable row level security;
alter table public.swap_disputes enable row level security;
alter table public.admin_actions enable row level security;

drop policy if exists "Users can create moderation reports" on public.moderation_reports;
create policy "Users can create moderation reports"
on public.moderation_reports
for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists "Users can read own moderation reports" on public.moderation_reports;
create policy "Users can read own moderation reports"
on public.moderation_reports
for select
to authenticated
using (reporter_id = auth.uid() or public.is_swaplibro_admin());

drop policy if exists "Admins can update moderation reports" on public.moderation_reports;
create policy "Admins can update moderation reports"
on public.moderation_reports
for update
to authenticated
using (public.is_swaplibro_admin())
with check (public.is_swaplibro_admin());

drop policy if exists "Participants can create swap disputes" on public.swap_disputes;
create policy "Participants can create swap disputes"
on public.swap_disputes
for insert
to authenticated
with check (
  opened_by = auth.uid()
  and exists (
    select 1
    from public.offers o
    where o.id = swap_disputes.offer_id
      and o.status in ('accepted', 'completed')
      and (o.maker_id = auth.uid() or o.owner_id = auth.uid())
      and (
        swap_disputes.item_id is null
        or swap_disputes.item_id::text = o.item_id
      )
  )
);

drop policy if exists "Participants can read own swap disputes" on public.swap_disputes;
create policy "Participants can read own swap disputes"
on public.swap_disputes
for select
to authenticated
using (
  opened_by = auth.uid()
  or against_user_id = auth.uid()
  or public.is_swaplibro_admin()
  or exists (
    select 1
    from public.offers o
    where o.id = swap_disputes.offer_id
      and (o.maker_id = auth.uid() or o.owner_id = auth.uid())
  )
);

drop policy if exists "Admins can update swap disputes" on public.swap_disputes;
create policy "Admins can update swap disputes"
on public.swap_disputes
for update
to authenticated
using (public.is_swaplibro_admin())
with check (public.is_swaplibro_admin());

drop policy if exists "Admins can create admin actions" on public.admin_actions;
create policy "Admins can create admin actions"
on public.admin_actions
for insert
to authenticated
with check (admin_id = auth.uid() and public.is_swaplibro_admin());

drop policy if exists "Admins can read admin actions" on public.admin_actions;
create policy "Admins can read admin actions"
on public.admin_actions
for select
to authenticated
using (public.is_swaplibro_admin());

-- Admin dashboard evidence access.
-- Participants keep the base app policies from swap_lifecycle.sql; these policies
-- add read access for admins reviewing disputes.

drop policy if exists "Admins can read conversations" on public.conversations;
create policy "Admins can read conversations"
on public.conversations
for select
to authenticated
using (public.is_swaplibro_admin());

drop policy if exists "Admins can read messages" on public.messages;
create policy "Admins can read messages"
on public.messages
for select
to authenticated
using (public.is_swaplibro_admin());

-- Admin dashboard catalog management.
-- Base catalog RLS only exposes active options publicly. Admins need full
-- read/write access to manage inactive categories and rollout cities.

drop policy if exists "Admins can read catalog categories" on public.catalog_categories;
create policy "Admins can read catalog categories"
on public.catalog_categories
for select
to authenticated
using (public.is_swaplibro_admin());

drop policy if exists "Admins can create catalog categories" on public.catalog_categories;
create policy "Admins can create catalog categories"
on public.catalog_categories
for insert
to authenticated
with check (public.is_swaplibro_admin());

drop policy if exists "Admins can update catalog categories" on public.catalog_categories;
create policy "Admins can update catalog categories"
on public.catalog_categories
for update
to authenticated
using (public.is_swaplibro_admin())
with check (public.is_swaplibro_admin());

drop policy if exists "Admins can read catalog locations" on public.catalog_locations;
create policy "Admins can read catalog locations"
on public.catalog_locations
for select
to authenticated
using (public.is_swaplibro_admin());

drop policy if exists "Admins can create catalog locations" on public.catalog_locations;
create policy "Admins can create catalog locations"
on public.catalog_locations
for insert
to authenticated
with check (public.is_swaplibro_admin());

drop policy if exists "Admins can update catalog locations" on public.catalog_locations;
create policy "Admins can update catalog locations"
on public.catalog_locations
for update
to authenticated
using (public.is_swaplibro_admin())
with check (public.is_swaplibro_admin());
