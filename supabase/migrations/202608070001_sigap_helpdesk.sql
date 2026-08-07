-- Sigap Helpdesk database foundation
-- Run this migration in Supabase SQL Editor or with `supabase db push`.

create extension if not exists "pgcrypto";

create type public.app_role as enum ('customer', 'agent', 'supervisor', 'admin');
create type public.ticket_status as enum ('open', 'in_progress', 'pending_customer', 'resolved', 'closed', 'reopened');
create type public.ticket_priority as enum ('low', 'medium', 'high', 'urgent');
create type public.ticket_channel as enum ('web', 'email');
create type public.assignment_strategy as enum ('round_robin', 'workload', 'manual');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  avatar_url text,
  role public.app_role not null default 'customer',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.sla_policies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  priority public.ticket_priority not null unique,
  first_response_mins integer not null check (first_response_mins > 0),
  resolution_mins integer not null check (resolution_mins > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number bigint generated always as identity unique,
  subject text not null check (char_length(subject) between 3 and 200),
  description text not null,
  customer_id uuid not null references public.profiles(id),
  assignee_id uuid references public.profiles(id),
  category_id uuid references public.categories(id),
  sla_policy_id uuid references public.sla_policies(id),
  priority public.ticket_priority not null default 'medium',
  status public.ticket_status not null default 'open',
  channel public.ticket_channel not null default 'web',
  first_response_at timestamptz,
  sla_first_response_due_at timestamptz,
  sla_resolution_due_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null check (char_length(body) > 0),
  is_internal boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  message_id uuid references public.ticket_messages(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id),
  file_path text not null,
  file_name text not null,
  file_size integer not null default 0 check (file_size >= 0),
  mime_type text,
  created_at timestamptz not null default now()
);

create table public.assignment_rules (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category_id uuid references public.categories(id) on delete cascade,
  priority public.ticket_priority,
  strategy public.assignment_strategy not null default 'workload',
  team_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.saved_replies (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  created_by uuid not null references public.profiles(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.kb_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.kb_articles (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.kb_categories(id) on delete set null,
  title text not null,
  slug text not null unique,
  excerpt text,
  content text not null,
  published boolean not null default false,
  views integer not null default 0 check (views >= 0),
  helpful_count integer not null default 0 check (helpful_count >= 0),
  not_helpful_count integer not null default 0 check (not_helpful_count >= 0),
  author_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.csat_ratings (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null unique references public.tickets(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  score integer not null check (score between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  ticket_id uuid references public.tickets(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null default 'info',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index tickets_customer_idx on public.tickets(customer_id, created_at desc);
create index tickets_assignee_idx on public.tickets(assignee_id, status, updated_at desc);
create index tickets_status_priority_idx on public.tickets(status, priority, created_at desc);
create index ticket_messages_ticket_idx on public.ticket_messages(ticket_id, created_at);
create index attachments_ticket_idx on public.attachments(ticket_id);
create index notifications_recipient_idx on public.notifications(recipient_id, read_at, created_at desc);
create index audit_logs_record_idx on public.audit_logs(table_name, record_id, created_at desc);
create index kb_articles_search_idx on public.kb_articles using gin (to_tsvector('simple', title || ' ' || coalesce(excerpt, '') || ' ' || content));

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('agent', 'supervisor', 'admin') and is_active);
$$;
create or replace function public.has_role(required_role public.app_role)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and (role = required_role or role = 'admin') and is_active);
$$;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.sla_policies enable row level security;
alter table public.tickets enable row level security;
alter table public.ticket_messages enable row level security;
alter table public.attachments enable row level security;
alter table public.assignment_rules enable row level security;
alter table public.saved_replies enable row level security;
alter table public.kb_categories enable row level security;
alter table public.kb_articles enable row level security;
alter table public.csat_ratings enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles can view active profiles" on public.profiles for select to authenticated using (is_active or id = auth.uid());
create policy "users can update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "staff manages profiles" on public.profiles for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy "authenticated users view categories" on public.categories for select to authenticated using (is_active or public.is_staff());
create policy "admins manage categories" on public.categories for all to authenticated using (public.has_role('admin')) with check (public.has_role('admin'));
create policy "authenticated users view sla" on public.sla_policies for select to authenticated using (is_active or public.is_staff());
create policy "admins manage sla" on public.sla_policies for all to authenticated using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "customers see own or staff sees tickets" on public.tickets for select to authenticated using (customer_id = auth.uid() or public.is_staff());
create policy "authenticated users create tickets" on public.tickets for insert to authenticated with check (customer_id = auth.uid() or public.is_staff());
create policy "staff updates tickets" on public.tickets for update to authenticated using (public.is_staff() or customer_id = auth.uid()) with check (public.is_staff() or customer_id = auth.uid());
create policy "admins delete tickets" on public.tickets for delete to authenticated using (public.has_role('admin'));

create policy "users see visible messages" on public.ticket_messages for select to authenticated using (exists (select 1 from public.tickets t where t.id = ticket_id and (t.customer_id = auth.uid() or public.is_staff())) and (not is_internal or public.is_staff()));
create policy "users add messages" on public.ticket_messages for insert to authenticated with check (sender_id = auth.uid() and exists (select 1 from public.tickets t where t.id = ticket_id and (t.customer_id = auth.uid() or public.is_staff())));
create policy "staff manages messages" on public.ticket_messages for update to authenticated using (public.is_staff()) with check (public.is_staff());

create policy "ticket participants view attachments" on public.attachments for select to authenticated using (uploaded_by = auth.uid() or public.is_staff() or exists (select 1 from public.tickets t where t.id = ticket_id and t.customer_id = auth.uid()));
create policy "ticket participants add attachments" on public.attachments for insert to authenticated with check (uploaded_by = auth.uid());
create policy "staff manages assignment rules" on public.assignment_rules for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff views saved replies" on public.saved_replies for select to authenticated using (public.is_staff());
create policy "staff manages saved replies" on public.saved_replies for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "all users view published articles" on public.kb_articles for select to authenticated using (published or public.is_staff());
create policy "staff manages articles" on public.kb_articles for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "all users view kb categories" on public.kb_categories for select to authenticated using (true);
create policy "staff manages kb categories" on public.kb_categories for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "customers manage own csat" on public.csat_ratings for all to authenticated using (customer_id = auth.uid() or public.is_staff()) with check (customer_id = auth.uid() or public.is_staff());
create policy "users view own notifications" on public.notifications for select to authenticated using (recipient_id = auth.uid());
create policy "users update own notifications" on public.notifications for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
create policy "staff view audit logs" on public.audit_logs for select to authenticated using (public.is_staff());

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger tickets_updated_at before update on public.tickets for each row execute function public.set_updated_at();
create trigger saved_replies_updated_at before update on public.saved_replies for each row execute function public.set_updated_at();
create trigger articles_updated_at before update on public.kb_articles for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.profiles(id, email, full_name) values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', '')); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.write_audit_log() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.audit_logs(actor_id, action, table_name, record_id, old_data, new_data) values (auth.uid(), TG_OP, TG_TABLE_NAME, coalesce(new.id, old.id), to_jsonb(old), to_jsonb(new)); return coalesce(new, old); end; $$;
create trigger tickets_audit after insert or update or delete on public.tickets for each row execute function public.write_audit_log();
create trigger profiles_audit after insert or update or delete on public.profiles for each row execute function public.write_audit_log();

create or replace function public.apply_sla_policy() returns trigger language plpgsql as $$ declare policy record; begin select * into policy from public.sla_policies where priority = new.priority and is_active limit 1; if policy.id is not null then new.sla_policy_id = policy.id; new.sla_first_response_due_at = new.created_at + make_interval(mins => policy.first_response_mins); new.sla_resolution_due_at = new.created_at + make_interval(mins => policy.resolution_mins); end if; return new; end; $$;
create trigger ticket_sla before insert on public.tickets for each row execute function public.apply_sla_policy();

insert into public.categories (name, description) values ('Akun & Akses', 'Masalah login dan akses akun'), ('Transaksi', 'Pertanyaan terkait transaksi'), ('Teknis', 'Gangguan teknis aplikasi'), ('Informasi Umum', 'Pertanyaan umum layanan') on conflict (name) do nothing;
insert into public.sla_policies (name, priority, first_response_mins, resolution_mins) values ('SLA Low', 'low', 480, 2880), ('SLA Medium', 'medium', 240, 1440), ('SLA High', 'high', 60, 480), ('SLA Urgent', 'urgent', 15, 120) on conflict (priority) do nothing;
insert into public.kb_categories (name) values ('Panduan Akun'), ('Transaksi'), ('Pertanyaan Umum') on conflict (name) do nothing;

alter publication supabase_realtime add table public.tickets;
alter publication supabase_realtime add table public.ticket_messages;
alter publication supabase_realtime add table public.notifications;
