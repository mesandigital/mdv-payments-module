-- SwapLibro swap lifecycle setup
-- Run after the base payments module, catalog module, and offers module SQL.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid unique references public.offers(id) on delete cascade,
  item_id uuid references public.items(id) on delete set null,
  requester_id uuid not null references auth.users(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.credit_holds (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid unique references public.offers(id) on delete cascade,
  item_id uuid references public.items(id) on delete set null,
  requester_id uuid not null references auth.users(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount > 0),
  status text not null default 'held'
    check (status in ('held', 'released', 'captured')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.swap_completions (
  offer_id uuid not null references public.offers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (offer_id, user_id)
);

create index if not exists credit_holds_requester_status_idx
on public.credit_holds (requester_id, status);

create index if not exists credit_holds_owner_status_idx
on public.credit_holds (owner_id, status);

create index if not exists swap_completions_user_idx
on public.swap_completions (user_id);

create index if not exists conversations_participants_idx
on public.conversations (requester_id, owner_id, updated_at desc);

create index if not exists messages_conversation_created_idx
on public.messages (conversation_id, created_at);

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at();

drop trigger if exists credit_holds_set_updated_at on public.credit_holds;
create trigger credit_holds_set_updated_at
before update on public.credit_holds
for each row
execute function public.set_updated_at();

alter table public.credit_holds enable row level security;
alter table public.swap_completions enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "Participants can read conversations" on public.conversations;
create policy "Participants can read conversations"
on public.conversations
for select
to authenticated
using (requester_id = auth.uid() or owner_id = auth.uid());

drop policy if exists "Participants can read messages" on public.messages;
create policy "Participants can read messages"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and (c.requester_id = auth.uid() or c.owner_id = auth.uid())
  )
);

drop policy if exists "Participants can send messages" on public.messages;
create policy "Participants can send messages"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.status = 'active'
      and (c.requester_id = auth.uid() or c.owner_id = auth.uid())
  )
);

drop policy if exists "Participants can read credit holds" on public.credit_holds;
create policy "Participants can read credit holds"
on public.credit_holds
for select
to authenticated
using (requester_id = auth.uid() or owner_id = auth.uid());

drop policy if exists "Participants can read swap completions" on public.swap_completions;
create policy "Participants can read swap completions"
on public.swap_completions
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.offers o
    where o.id = swap_completions.offer_id
      and (o.maker_id = auth.uid() or o.owner_id = auth.uid())
  )
);

create or replace function public.log_swap_event(
  p_offer_id uuid,
  p_event_type text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if to_regclass('public.offer_events') is not null then
    insert into public.offer_events (offer_id, actor_id, event_type, metadata)
    values (p_offer_id, auth.uid(), p_event_type, coalesce(p_metadata, '{}'::jsonb));
  end if;
end;
$$;

create or replace function public.release_swap_hold(
  p_offer_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hold public.credit_holds;
begin
  select *
  into v_hold
  from public.credit_holds
  where offer_id = p_offer_id
  for update;

  if not found or v_hold.status <> 'held' then
    return;
  end if;

  update public.credit_holds
  set status = 'released'
  where id = v_hold.id;

  update public.credit_balances
  set balance = balance + v_hold.amount
  where user_id = v_hold.requester_id;

  insert into public.credit_ledger (user_id, delta, reason, metadata)
  values (
    v_hold.requester_id,
    v_hold.amount,
    p_reason,
    jsonb_build_object('offerId', p_offer_id, 'itemId', v_hold.item_id)
  );
end;
$$;

create or replace function public.request_swap(
  p_item_id uuid,
  p_credits integer,
  p_message text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns public.offers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.items;
  v_offer public.offers;
  v_balance integer;
  v_credits integer := greatest(0, coalesce(p_credits, 0));
begin
  select *
  into v_item
  from public.items
  where id = p_item_id
  for update;

  if not found then
    raise exception 'Book not found';
  end if;

  if v_item.owner_id is null then
    raise exception 'This book has no owner';
  end if;

  if v_item.owner_id = auth.uid() then
    raise exception 'You cannot request your own book';
  end if;

  if v_item.status <> 'available' then
    raise exception 'This book is not available';
  end if;

  if exists (
    select 1
    from public.offers
    where item_id = p_item_id::text
      and maker_id = auth.uid()
      and status in ('pending', 'accepted')
  ) then
    raise exception 'You already have an active request for this book';
  end if;

  insert into public.credit_balances (user_id, balance)
  values (auth.uid(), 0)
  on conflict (user_id) do nothing;

  select balance
  into v_balance
  from public.credit_balances
  where user_id = auth.uid()
  for update;

  if v_balance < v_credits then
    raise exception 'Insufficient credits';
  end if;

  if v_credits > 0 then
    update public.credit_balances
    set balance = balance - v_credits
    where user_id = auth.uid();

    insert into public.credit_ledger (user_id, delta, reason, metadata)
    values (
      auth.uid(),
      -v_credits,
      'swap_hold',
      jsonb_build_object('itemId', p_item_id, 'ownerId', v_item.owner_id)
    );
  end if;

  insert into public.offers (
    item_id,
    maker_id,
    owner_id,
    kind,
    status,
    credits,
    message,
    metadata
  )
  values (
    p_item_id::text,
    auth.uid(),
    v_item.owner_id,
    'swap',
    'pending',
    v_credits,
    p_message,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_offer;

  if v_credits > 0 then
    insert into public.credit_holds (
      offer_id,
      item_id,
      requester_id,
      owner_id,
      amount,
      status,
      metadata
    )
    values (
      v_offer.id,
      p_item_id,
      auth.uid(),
      v_item.owner_id,
      v_credits,
      'held',
      jsonb_build_object('itemTitle', v_item.title)
    );
  end if;

  perform public.log_swap_event(v_offer.id, 'requested', jsonb_build_object('credits', v_credits));

  return v_offer;
end;
$$;

create or replace function public.accept_swap_request(p_offer_id uuid)
returns public.offers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.offers;
  v_conversation_id uuid;
  v_expired_hold record;
begin
  select *
  into v_offer
  from public.offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_offer.owner_id <> auth.uid() then
    raise exception 'Only the book owner can accept this request';
  end if;

  if v_offer.status <> 'pending' then
    raise exception 'Only pending requests can be accepted';
  end if;

  update public.offers
  set status = 'accepted'
  where id = p_offer_id
  returning * into v_offer;

  update public.items
  set status = 'reserved'
  where id = v_offer.item_id::uuid;

  insert into public.conversations (
    offer_id,
    item_id,
    requester_id,
    owner_id,
    status
  )
  values (
    p_offer_id,
    v_offer.item_id::uuid,
    v_offer.maker_id,
    v_offer.owner_id,
    'active'
  )
  on conflict (offer_id)
  do update set status = 'active'
  returning id into v_conversation_id;

  update public.offers
  set conversation_id = v_conversation_id
  where id = p_offer_id
  returning * into v_offer;

  update public.offers
  set status = 'expired'
  where item_id = v_offer.item_id
    and id <> p_offer_id
    and status = 'pending';

  for v_expired_hold in
    select offer_id
    from public.credit_holds
    where offer_id in (
      select id
      from public.offers
      where item_id = v_offer.item_id
        and id <> p_offer_id
        and status = 'expired'
    )
      and status = 'held'
  loop
    perform public.release_swap_hold(v_expired_hold.offer_id, 'swap_expired_refund');
  end loop;

  perform public.log_swap_event(p_offer_id, 'accepted');

  return v_offer;
end;
$$;

create or replace function public.decline_swap_request(p_offer_id uuid)
returns public.offers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.offers;
begin
  select *
  into v_offer
  from public.offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_offer.owner_id <> auth.uid() then
    raise exception 'Only the book owner can decline this request';
  end if;

  if v_offer.status <> 'pending' then
    raise exception 'Only pending requests can be declined';
  end if;

  update public.offers
  set status = 'declined'
  where id = p_offer_id
  returning * into v_offer;

  perform public.release_swap_hold(p_offer_id, 'swap_declined_refund');
  perform public.log_swap_event(p_offer_id, 'declined');

  return v_offer;
end;
$$;

create or replace function public.cancel_swap_request(p_offer_id uuid)
returns public.offers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.offers;
begin
  select *
  into v_offer
  from public.offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_offer.maker_id <> auth.uid() then
    raise exception 'Only the requester can cancel this request';
  end if;

  if v_offer.status <> 'pending' then
    raise exception 'Only pending requests can be cancelled';
  end if;

  update public.offers
  set status = 'cancelled'
  where id = p_offer_id
  returning * into v_offer;

  perform public.release_swap_hold(p_offer_id, 'swap_cancelled_refund');
  perform public.log_swap_event(p_offer_id, 'cancelled');

  return v_offer;
end;
$$;

create or replace function public.mark_swap_complete(p_offer_id uuid)
returns public.offers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.offers;
  v_hold public.credit_holds;
  v_completion_count integer;
begin
  select *
  into v_offer
  from public.offers
  where id = p_offer_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_offer.maker_id <> auth.uid() and v_offer.owner_id <> auth.uid() then
    raise exception 'Only swap participants can complete this request';
  end if;

  if v_offer.status <> 'accepted' then
    raise exception 'Only accepted requests can be completed';
  end if;

  insert into public.swap_completions (offer_id, user_id)
  values (p_offer_id, auth.uid())
  on conflict (offer_id, user_id) do nothing;

  select count(*)
  into v_completion_count
  from public.swap_completions
  where offer_id = p_offer_id
    and user_id in (v_offer.maker_id, v_offer.owner_id);

  perform public.log_swap_event(
    p_offer_id,
    'completion_marked',
    jsonb_build_object('count', v_completion_count)
  );

  if v_completion_count < 2 then
    return v_offer;
  end if;

  select *
  into v_hold
  from public.credit_holds
  where offer_id = p_offer_id
  for update;

  if found and v_hold.status = 'held' then
    update public.credit_holds
    set status = 'captured'
    where id = v_hold.id;

    insert into public.credit_balances (user_id, balance)
    values (v_hold.owner_id, 0)
    on conflict (user_id) do nothing;

    update public.credit_balances
    set balance = balance + v_hold.amount
    where user_id = v_hold.owner_id;

    insert into public.credit_ledger (user_id, delta, reason, metadata)
    values (
      v_hold.owner_id,
      v_hold.amount,
      'swap_completed_credit',
      jsonb_build_object('offerId', p_offer_id, 'itemId', v_hold.item_id)
    );
  end if;

  update public.offers
  set status = 'completed'
  where id = p_offer_id
  returning * into v_offer;

  update public.items
  set status = 'sold'
  where id = v_offer.item_id::uuid;

  perform public.log_swap_event(p_offer_id, 'completed');

  return v_offer;
end;
$$;

grant execute on function public.request_swap(uuid, integer, text, jsonb) to authenticated;
grant execute on function public.accept_swap_request(uuid) to authenticated;
grant execute on function public.decline_swap_request(uuid) to authenticated;
grant execute on function public.cancel_swap_request(uuid) to authenticated;
grant execute on function public.mark_swap_complete(uuid) to authenticated;
