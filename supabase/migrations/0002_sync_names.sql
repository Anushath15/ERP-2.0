-- ASK ERP 2.0, Gate 2E: the collection names are the app's table names (snake_case), and only rows that never change once written are
-- append-only. Bills and purchases are edited (status, payment marks), so they follow last-writer-wins like products.
-- Run once in Supabase > SQL Editor, after 0001_sync.sql.

create or replace function public.is_append_only(p_coll text) returns boolean language sql immutable as $$
  select p_coll = any (array['bill_lines','bill_cancellations','sales_returns','sales_return_lines','purchase_lines',
                             'purchase_returns','purchase_return_lines','stock_movements','ledger_entries','payments',
                             'reminders','audit']);
$$;
