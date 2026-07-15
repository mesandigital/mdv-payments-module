-- SwapLibro listing inquiries setup
-- Run after catalog and offers SQL. Run before notifications.sql if notification triggers are enabled.

create extension if not exists pgcrypto;

create table if not exists public.listing_inquiries (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  asker_id uuid not null references auth.users(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  question text not null check (length(trim(question)) > 0),
  answer text,
  answered_by uuid references auth.users(id) on delete set null,
  answered_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists listing_inquiries_item_created_idx
on public.listing_inquiries (item_id, created_at desc);

create index if not exists listing_inquiries_asker_created_idx
on public.listing_inquiries (asker_id, created_at desc);

create index if not exists listing_inquiries_owner_created_idx
on public.listing_inquiries (owner_id, created_at desc);

drop trigger if exists listing_inquiries_set_updated_at on public.listing_inquiries;
create trigger listing_inquiries_set_updated_at
before update on public.listing_inquiries
for each row
execute function public.set_updated_at();

alter table public.listing_inquiries enable row level security;

drop policy if exists "Participants can read listing inquiries" on public.listing_inquiries;
create policy "Participants can read listing inquiries"
on public.listing_inquiries
for select
to authenticated
using (asker_id = auth.uid() or owner_id = auth.uid());

drop policy if exists "Members can ask listing questions" on public.listing_inquiries;
create policy "Members can ask listing questions"
on public.listing_inquiries
for insert
to authenticated
with check (
  asker_id = auth.uid()
  and owner_id <> auth.uid()
  and exists (
    select 1
    from public.items i
    where i.id = listing_inquiries.item_id
      and i.owner_id = listing_inquiries.owner_id
  )
);

drop policy if exists "Owners can answer listing inquiries" on public.listing_inquiries;
create policy "Owners can answer listing inquiries"
on public.listing_inquiries
for update
to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and answered_by = auth.uid()
);
