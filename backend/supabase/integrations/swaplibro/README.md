# SwapLibro Payment And Swap Lifecycle SQL

Apply the base payments module first, then the catalog and offers module Supabase scripts, then the SwapLibro integration scripts.

Recommended order:

1. `node_modules/mdv-payments-module/backend/supabase/schema.sql`
2. `node_modules/mdv-payments-module/backend/supabase/indexes.sql`
3. `node_modules/mdv-payments-module/backend/supabase/rls.sql`
4. `node_modules/mdv-catalog-module/backend/supabase/schema.sql`
5. `node_modules/mdv-catalog-module/backend/supabase/indexes.sql`
6. `node_modules/mdv-catalog-module/backend/supabase/rls.sql`
7. `node_modules/mdv-catalog-module/backend/supabase/storage.sql`
8. `node_modules/mdv-catalog-module/backend/supabase/seed.sql`
9. `node_modules/mdv-offers-module/backend/supabase/schema.sql`
10. `node_modules/mdv-offers-module/backend/supabase/indexes.sql`
11. `node_modules/mdv-offers-module/backend/supabase/rls.sql`
12. `integrations/swaplibro/swap_lifecycle.sql`
13. `integrations/swaplibro/listing_inquiries.sql`
14. `integrations/swaplibro/user_reviews.sql`
15. `integrations/swaplibro/moderation.sql`
16. `integrations/swaplibro/notifications.sql`

The app now expects these RPCs:

- `adjust_credit_balance`
- `request_swap`
- `accept_swap_request`
- `decline_swap_request`
- `cancel_swap_request`
- `mark_swap_complete`

Credit behavior:

- Requesting a swap creates an offer and moves requester credits into a hold.
- Cancelling or declining a pending request refunds the hold.
- Accepting a request reserves the item and expires competing pending requests.
- Marking complete records participant confirmation.
- After both participants mark complete, the hold is captured and credits are granted to the book owner.
- After a completed swap, each participant can leave one review for the counterparty.
- Users can report listings/profiles and open swap disputes; admins are identified by `profiles.metadata.role = admin` or equivalent admin flags.
- Admins can review moderation reports, inspect dispute chat/photo evidence, update dispute/report statuses, write `admin_actions`, and manage active catalog categories/cities.
