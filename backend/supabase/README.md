# Supabase Backend Setup

This starter kit creates the credit balance and ledger backend for `mdv-payments-module`.

It includes:

- `credit_balances` for per-user balances.
- `credit_ledger` for immutable credit history rows.
- `adjust_credit_balance(...)` for atomic grant/spend updates.

## Files

```txt
backend/supabase/
  schema.sql
  indexes.sql
  rls.sql
  seed.sql
  README.md
```

## Apply In Supabase Dashboard

1. Open Supabase Dashboard.
2. Select your project.
3. Open SQL Editor.
4. Run `schema.sql`.
5. Run `indexes.sql`.
6. Run `rls.sql`.
7. Optionally edit and run `seed.sql`.

## Apply With Supabase CLI

Copy the SQL into your app's Supabase migrations directory:

```txt
supabase/migrations/001_create_credit_balances.sql
supabase/migrations/002_create_credit_indexes.sql
supabase/migrations/003_credit_rls.sql
supabase/migrations/004_credit_seed.sql
```

Then run:

```sh
supabase db push
```

## Client Adapter

Use `PaymentsProvider` with a `creditGrantAdapter` so successful purchases can grant credits into your backend ledger.

The module does not own the user balance UI state. The host app should read `credit_balances` and `credit_ledger` to render current balance and history.

## Notes

- Credits are granted by your backend or app database after RevenueCat confirms the purchase.
- The `adjust_credit_balance(...)` RPC rejects overspends instead of silently clamping to zero.
- The ledger table keeps an append-only audit trail for all credit adjustments.
