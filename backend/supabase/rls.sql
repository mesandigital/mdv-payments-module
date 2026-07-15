-- mdv-payments-module Supabase RLS
alter table public.credit_balances enable row level security;
alter table public.credit_ledger enable row level security;

drop policy if exists "Users can read their own credit balance" on public.credit_balances;
create policy "Users can read their own credit balance"
on public.credit_balances
for select
using (auth.uid() = user_id);

drop policy if exists "Users can upsert their own credit balance" on public.credit_balances;
create policy "Users can upsert their own credit balance"
on public.credit_balances
for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own credit balance" on public.credit_balances;
create policy "Users can update their own credit balance"
on public.credit_balances
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can read their own credit ledger" on public.credit_ledger;
create policy "Users can read their own credit ledger"
on public.credit_ledger
for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert their own credit ledger" on public.credit_ledger;
create policy "Users can insert their own credit ledger"
on public.credit_ledger
for insert
with check (auth.uid() = user_id);
