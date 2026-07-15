-- SwapLibro user reviews setup
-- Run after swap_lifecycle.sql. Run before notifications.sql if review notifications are added later.

create extension if not exists pgcrypto;

create table if not exists public.user_reviews (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.offers(id) on delete cascade,
  item_id uuid references public.items(id) on delete set null,
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  reviewee_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (offer_id, reviewer_id),
  check (reviewer_id <> reviewee_id)
);

create index if not exists user_reviews_reviewee_created_idx
on public.user_reviews (reviewee_id, created_at desc);

create index if not exists user_reviews_reviewer_created_idx
on public.user_reviews (reviewer_id, created_at desc);

create index if not exists user_reviews_offer_idx
on public.user_reviews (offer_id);

alter table public.user_reviews enable row level security;

drop policy if exists "Authenticated users can read reviews" on public.user_reviews;
create policy "Authenticated users can read reviews"
on public.user_reviews
for select
to authenticated
using (true);

drop policy if exists "Participants can review completed swaps" on public.user_reviews;
create policy "Participants can review completed swaps"
on public.user_reviews
for insert
to authenticated
with check (
  reviewer_id = auth.uid()
  and exists (
    select 1
    from public.offers o
    where o.id = user_reviews.offer_id
      and o.status = 'completed'
      and (
        (o.maker_id = auth.uid() and o.owner_id = user_reviews.reviewee_id)
        or
        (o.owner_id = auth.uid() and o.maker_id = user_reviews.reviewee_id)
      )
      and (
        user_reviews.item_id is null
        or user_reviews.item_id::text = o.item_id
      )
  )
);
