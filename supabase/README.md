# Supabase setup

1. Open the Supabase project SQL Editor.
2. Run the migration in `migrations/202608070001_sigap_helpdesk.sql`.
3. Copy the project URL and anon key into the local `.env.local` file.
4. Enable Email provider in Authentication > Providers.
5. Optionally enable Realtime for the migrated tables (the migration adds the core tables).

The migration creates all MVP tables, role-aware RLS policies, timestamps, user profile creation, SLA defaults, audit logging, and seed reference data. Do not commit `.env.local` or service-role credentials.
