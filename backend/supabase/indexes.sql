-- mdv-payments-module Supabase indexes
create index if not exists credit_balances_updated_at_idx
  on public.credit_balances (updated_at desc);

create index if not exists credit_ledger_user_id_reason_idx
  on public.credit_ledger (user_id, reason, created_at desc);

create index if not exists credit_ledger_created_at_idx
  on public.credit_ledger (created_at desc);
