-- SwapLibro notifications setup
-- Run after swap_lifecycle.sql.

create extension if not exists pgcrypto;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  type text not null,
  title text not null,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_unread_idx
on public.notifications (user_id, read_at)
where read_at is null;

alter table public.notifications enable row level security;

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.notify_user(
  p_user_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;

  insert into public.notifications (
    user_id,
    actor_id,
    type,
    title,
    body,
    metadata
  )
  values (
    p_user_id,
    p_actor_id,
    p_type,
    p_title,
    p_body,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

create or replace function public.notify_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.conversations;
  v_recipient_id uuid;
begin
  select *
  into v_conversation
  from public.conversations
  where id = new.conversation_id;

  if not found then
    return new;
  end if;

  v_recipient_id := case
    when new.sender_id = v_conversation.requester_id then v_conversation.owner_id
    else v_conversation.requester_id
  end;

  perform public.notify_user(
    v_recipient_id,
    new.sender_id,
    'message_received',
    'New message',
    left(new.body, 120),
    jsonb_build_object(
      'conversationId', new.conversation_id,
      'offerId', v_conversation.offer_id,
      'itemId', v_conversation.item_id
    )
  );

  return new;
end;
$$;

drop trigger if exists messages_notify_insert on public.messages;
create trigger messages_notify_insert
after insert on public.messages
for each row
execute function public.notify_message_insert();

create or replace function public.notify_offer_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kind = 'swap' and new.status = 'pending' then
    perform public.notify_user(
      new.owner_id,
      new.maker_id,
      'swap_requested',
      'New book request',
      'Someone requested your book.',
      jsonb_build_object('offerId', new.id, 'itemId', new.item_id, 'credits', new.credits)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists offers_notify_insert on public.offers;
create trigger offers_notify_insert
after insert on public.offers
for each row
execute function public.notify_offer_insert();

create or replace function public.notify_offer_status_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = new.status then
    return new;
  end if;

  if new.status = 'accepted' then
    perform public.notify_user(
      new.maker_id,
      new.owner_id,
      'swap_accepted',
      'Request accepted',
      'Your book request was accepted. You can now chat to arrange the swap.',
      jsonb_build_object('offerId', new.id, 'itemId', new.item_id, 'conversationId', new.conversation_id)
    );
  elsif new.status = 'declined' then
    perform public.notify_user(
      new.maker_id,
      new.owner_id,
      'swap_declined',
      'Request declined',
      'Your book request was declined and your credits were refunded.',
      jsonb_build_object('offerId', new.id, 'itemId', new.item_id)
    );
  elsif new.status = 'cancelled' then
    perform public.notify_user(
      new.owner_id,
      new.maker_id,
      'swap_cancelled',
      'Request cancelled',
      'A requester cancelled their book request.',
      jsonb_build_object('offerId', new.id, 'itemId', new.item_id)
    );
  elsif new.status = 'completed' then
    perform public.notify_user(
      new.maker_id,
      new.owner_id,
      'swap_completed',
      'Swap completed',
      'Both members confirmed the swap.',
      jsonb_build_object('offerId', new.id, 'itemId', new.item_id)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists offers_notify_status_update on public.offers;
create trigger offers_notify_status_update
after update of status on public.offers
for each row
execute function public.notify_offer_status_update();

create or replace function public.notify_swap_completion_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.offers;
  v_recipient_id uuid;
  v_completion_count integer;
begin
  select *
  into v_offer
  from public.offers
  where id = new.offer_id;

  if not found then
    return new;
  end if;

  v_recipient_id := case
    when new.user_id = v_offer.maker_id then v_offer.owner_id
    else v_offer.maker_id
  end;

  select count(*)
  into v_completion_count
  from public.swap_completions
  where offer_id = new.offer_id;

  perform public.notify_user(
    v_recipient_id,
    new.user_id,
    'swap_completion_marked',
    'Swap marked complete',
    'The other member marked this swap as complete.',
    jsonb_build_object(
      'offerId', new.offer_id,
      'itemId', v_offer.item_id,
      'completionCount', v_completion_count
    )
  );

  return new;
end;
$$;

drop trigger if exists swap_completions_notify_insert on public.swap_completions;
create trigger swap_completions_notify_insert
after insert on public.swap_completions
for each row
execute function public.notify_swap_completion_insert();

create or replace function public.notify_credit_ledger_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.reason = 'swap_completed_credit' then
    perform public.notify_user(
      new.user_id,
      null,
      'credits_released',
      'Credits released',
      'The swap is complete and credits were released to you.',
      coalesce(new.metadata, '{}'::jsonb)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists credit_ledger_notify_insert on public.credit_ledger;
create trigger credit_ledger_notify_insert
after insert on public.credit_ledger
for each row
execute function public.notify_credit_ledger_insert();

create or replace function public.notify_listing_inquiry_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_user(
    new.owner_id,
    new.asker_id,
    'listing_inquiry_received',
    'Question about your book',
    left(new.question, 120),
    jsonb_build_object('itemId', new.item_id, 'inquiryId', new.id)
  );

  return new;
end;
$$;

drop trigger if exists listing_inquiries_notify_insert on public.listing_inquiries;
create trigger listing_inquiries_notify_insert
after insert on public.listing_inquiries
for each row
execute function public.notify_listing_inquiry_insert();

create or replace function public.notify_listing_inquiry_answer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.answer is not null or new.answer is null then
    return new;
  end if;

  perform public.notify_user(
    new.asker_id,
    new.owner_id,
    'listing_inquiry_answered',
    'Your question was answered',
    left(new.answer, 120),
    jsonb_build_object('itemId', new.item_id, 'inquiryId', new.id)
  );

  return new;
end;
$$;

drop trigger if exists listing_inquiries_notify_answer on public.listing_inquiries;
create trigger listing_inquiries_notify_answer
after update of answer on public.listing_inquiries
for each row
execute function public.notify_listing_inquiry_answer();
