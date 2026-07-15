-- mdv-payments-module Supabase schema
create table if not exists public.credit_balances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  delta integer not null,
  reason text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists credit_ledger_user_id_created_at_idx
  on public.credit_ledger (user_id, created_at desc);

create or replace function public.adjust_credit_balance(
  p_user_id uuid,
  p_delta integer,
  p_reason text default null,
  p_metadata jsonb default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_balance integer;
  v_next_balance integer;
begin
  insert into public.credit_balances (user_id, balance, updated_at)
  values (p_user_id, 0, now())
  on conflict (user_id)
  do nothing;

  select balance
    into v_current_balance
  from public.credit_balances
  where user_id = p_user_id
  for update;

  if p_delta < 0 and coalesce(v_current_balance, 0) + p_delta < 0 then
    raise exception 'Not enough credits. Need %, have %.', abs(p_delta), coalesce(v_current_balance, 0);
  end if;

  v_next_balance := greatest(0, coalesce(v_current_balance, 0) + p_delta);

  update public.credit_balances
  set balance = v_next_balance,
      updated_at = now()
  where user_id = p_user_id;

  insert into public.credit_ledger (user_id, delta, reason, metadata)
  values (p_user_id, p_delta, p_reason, p_metadata);

  return v_next_balance;
end;
$$;
