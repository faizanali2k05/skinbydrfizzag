-- Skin By Dr. Fizza G - Supabase database setup / repair script
-- Safe to run in Supabase SQL Editor. It does NOT drop existing tables/data.
-- After running, PostgREST schema cache is refreshed automatically at the end.

create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

----------------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------------
create or replace function public.trigger_set_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
end;
$$ language plpgsql security definer;

----------------------------------------------------------------------
-- Core tables
----------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key,
  full_name text,
  email text,
  phone text,
  role text not null default 'user',
  photo_url text,
  status text not null default 'active',
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists role text not null default 'user';
alter table public.profiles add column if not exists photo_url text;
alter table public.profiles add column if not exists status text not null default 'active';
alter table public.profiles add column if not exists fcm_token text;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();
alter table public.profiles add column if not exists deleted_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_role_check'
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('admin', 'user'));
  end if;
end $$;

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_email_idx on public.profiles (email);

drop trigger if exists profiles_set_timestamp on public.profiles;
create trigger profiles_set_timestamp
  before update on public.profiles
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null default 'app',
  last_message text,
  last_sender_id uuid,
  unread_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.conversations add column if not exists platform text not null default 'app';
alter table public.conversations add column if not exists last_message text;
alter table public.conversations add column if not exists last_sender_id uuid;
alter table public.conversations add column if not exists unread_count int not null default 0;
alter table public.conversations add column if not exists created_at timestamptz not null default now();
alter table public.conversations add column if not exists updated_at timestamptz not null default now();

create index if not exists conversations_user_id_idx on public.conversations (user_id);
create index if not exists conversations_admin_id_idx on public.conversations (admin_id);
create index if not exists conversations_updated_at_idx on public.conversations (updated_at);
create index if not exists conversations_platform_idx on public.conversations (platform);

drop trigger if exists conversations_set_timestamp on public.conversations;
create trigger conversations_set_timestamp
  before update on public.conversations
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  sender_name text,
  sender_role text not null default 'user',
  message_type text not null default 'text',
  text text not null,
  file_url text,
  is_read boolean not null default false,
  platform text not null default 'app',
  whatsapp_message_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.messages add column if not exists sender_name text;
alter table public.messages add column if not exists sender_role text not null default 'user';
alter table public.messages add column if not exists message_type text not null default 'text';
alter table public.messages add column if not exists file_url text;
alter table public.messages add column if not exists is_read boolean not null default false;
alter table public.messages add column if not exists platform text not null default 'app';
alter table public.messages add column if not exists whatsapp_message_id text;
alter table public.messages add column if not exists created_at timestamptz not null default now();
alter table public.messages add column if not exists updated_at timestamptz not null default now();

create index if not exists messages_conversation_id_idx on public.messages (conversation_id);
create index if not exists messages_sender_id_idx on public.messages (sender_id);
create index if not exists messages_created_at_idx on public.messages (created_at);

drop trigger if exists messages_set_timestamp on public.messages;
create trigger messages_set_timestamp
  before update on public.messages
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.procedures (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text default 'GENERAL',
  price numeric(10,2) not null default 0,
  duration int not null default 0,
  sessions int not null default 1,
  visits_per_session int not null default 1,
  key_features text[] default '{}',
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.procedures add column if not exists description text;
alter table public.procedures add column if not exists category text default 'GENERAL';
alter table public.procedures add column if not exists price numeric(10,2) not null default 0;
alter table public.procedures add column if not exists duration int not null default 0;
alter table public.procedures add column if not exists sessions int not null default 1;
alter table public.procedures add column if not exists visits_per_session int not null default 1;
alter table public.procedures add column if not exists key_features text[] default '{}';
alter table public.procedures add column if not exists image_url text;
alter table public.procedures add column if not exists created_at timestamptz not null default now();
alter table public.procedures add column if not exists updated_at timestamptz not null default now();
alter table public.procedures add column if not exists deleted_at timestamptz;

create index if not exists procedures_title_idx on public.procedures (title);

drop trigger if exists procedures_set_timestamp on public.procedures;
create trigger procedures_set_timestamp
  before update on public.procedures
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  user_name text,
  doctor_id uuid references public.profiles(id) on delete set null,
  procedure_id uuid references public.procedures(id) on delete set null,
  procedure_name text,
  scheduled_at timestamptz not null,
  status text not null default 'pending',
  notes text,
  admin_notes text,
  session_number int not null default 1,
  visit_number int not null default 1,
  clinic_location text,
  original_scheduled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.appointments add column if not exists user_name text;
alter table public.appointments add column if not exists doctor_id uuid references public.profiles(id) on delete set null;
alter table public.appointments add column if not exists procedure_name text;
alter table public.appointments add column if not exists status text not null default 'pending';
alter table public.appointments add column if not exists notes text;
alter table public.appointments add column if not exists admin_notes text;
alter table public.appointments add column if not exists session_number int not null default 1;
alter table public.appointments add column if not exists visit_number int not null default 1;
alter table public.appointments add column if not exists clinic_location text;
alter table public.appointments add column if not exists original_scheduled_at timestamptz;
alter table public.appointments add column if not exists created_at timestamptz not null default now();
alter table public.appointments add column if not exists updated_at timestamptz not null default now();
alter table public.appointments add column if not exists deleted_at timestamptz;

create index if not exists appointments_user_id_idx on public.appointments (user_id);
create index if not exists appointments_procedure_id_idx on public.appointments (procedure_id);
create index if not exists appointments_scheduled_at_idx on public.appointments (scheduled_at);
create index if not exists appointments_status_idx on public.appointments (status);

drop trigger if exists appointments_set_timestamp on public.appointments;
create trigger appointments_set_timestamp
  before update on public.appointments
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null,
  appointment_id uuid,
  conversation_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notifications add column if not exists appointment_id uuid;
alter table public.notifications add column if not exists conversation_id uuid;
alter table public.notifications add column if not exists is_read boolean not null default false;
alter table public.notifications add column if not exists created_at timestamptz not null default now();
alter table public.notifications add column if not exists updated_at timestamptz not null default now();

create index if not exists notifications_user_id_idx on public.notifications (user_id);
create index if not exists notifications_is_read_idx on public.notifications (is_read);

drop trigger if exists notifications_set_timestamp on public.notifications;
create trigger notifications_set_timestamp
  before update on public.notifications
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.about_us (
  id serial primary key,
  description text,
  email text,
  phone text,
  instagram_url text,
  facebook_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.about_us add column if not exists description text;
alter table public.about_us add column if not exists email text;
alter table public.about_us add column if not exists phone text;
alter table public.about_us add column if not exists instagram_url text;
alter table public.about_us add column if not exists facebook_url text;
alter table public.about_us add column if not exists created_at timestamptz not null default now();
alter table public.about_us add column if not exists updated_at timestamptz not null default now();

insert into public.about_us (id, description)
values (1, 'Clinic Information')
on conflict (id) do nothing;

drop trigger if exists about_us_set_timestamp on public.about_us;
create trigger about_us_set_timestamp
  before update on public.about_us
  for each row execute function public.trigger_set_timestamp();

create table if not exists public.clinic_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  phone text,
  email text,
  map_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.clinic_locations add column if not exists phone text;
alter table public.clinic_locations add column if not exists email text;
alter table public.clinic_locations add column if not exists map_url text;
alter table public.clinic_locations add column if not exists sort_order int not null default 0;
alter table public.clinic_locations add column if not exists is_active boolean not null default true;
alter table public.clinic_locations add column if not exists created_at timestamptz not null default now();
alter table public.clinic_locations add column if not exists updated_at timestamptz not null default now();

create index if not exists clinic_locations_sort_order_idx on public.clinic_locations (sort_order);
create index if not exists clinic_locations_is_active_idx on public.clinic_locations (is_active);

insert into public.clinic_locations (name, address, sort_order)
select 'Main Clinic', 'Lahore, Pakistan', 0
where not exists (select 1 from public.clinic_locations);

drop trigger if exists clinic_locations_set_timestamp on public.clinic_locations;
create trigger clinic_locations_set_timestamp
  before update on public.clinic_locations
  for each row execute function public.trigger_set_timestamp();

----------------------------------------------------------------------
-- AI chat tables
----------------------------------------------------------------------
create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  sender text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_conversations_user_id_idx on public.ai_conversations (user_id);
create index if not exists ai_messages_conversation_id_idx on public.ai_messages (conversation_id);

drop trigger if exists ai_conversations_set_timestamp on public.ai_conversations;
create trigger ai_conversations_set_timestamp
  before update on public.ai_conversations
  for each row execute function public.trigger_set_timestamp();

----------------------------------------------------------------------
-- Auth profile trigger
----------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    new.email,
    new.raw_user_meta_data->>'phone',
    'user'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, email, role)
select id, coalesce(raw_user_meta_data->>'full_name', 'User'), email, 'user'
from auth.users
on conflict (id) do nothing;

----------------------------------------------------------------------
-- Business triggers
----------------------------------------------------------------------
create or replace function public.handle_new_message_logic()
returns trigger as $$
declare
  notif_message text;
begin
  if (new.message_type = 'text') then
    notif_message := new.text;
  elsif (new.message_type = 'image') then
    notif_message := 'Sent an image';
  elsif (new.message_type = 'voice' or new.message_type = 'audio') then
    notif_message := 'Sent a voice message';
  else
    notif_message := 'Sent a file';
  end if;

  update public.conversations
  set
    last_message = notif_message,
    last_sender_id = new.sender_id,
    unread_count = unread_count + 1,
    updated_at = now()
  where id = new.conversation_id;

  if (new.sender_role <> 'admin') then
    insert into public.notifications (user_id, title, message, type, conversation_id)
    select
      admin_id,
      'New Message from User',
      notif_message,
      'message',
      new.conversation_id
    from public.conversations
    where id = new.conversation_id;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_new_message on public.messages;
create trigger on_new_message
  after insert on public.messages
  for each row execute function public.handle_new_message_logic();

create or replace function public.handle_appointment_notification()
returns trigger as $$
declare
  proc_title text;
begin
  select title into proc_title from public.procedures where id = new.procedure_id;
  proc_title := coalesce(new.procedure_name, proc_title, 'Procedure');

  if (tg_op = 'INSERT') then
    insert into public.notifications (user_id, title, message, type, appointment_id)
    values (
      new.user_id,
      'New Appointment',
      'Your appointment for ' || proc_title || ' has been booked.',
      'appointment',
      new.id
    );
  elsif (tg_op = 'UPDATE' and old.status <> new.status) then
    insert into public.notifications (user_id, title, message, type, appointment_id)
    values (
      new.user_id,
      'Appointment Updated',
      'Your appointment for ' || proc_title || ' is now ' || new.status || '.',
      'appointment',
      new.id
    );
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_appointment_change on public.appointments;
create trigger on_appointment_change
  after insert or update on public.appointments
  for each row execute function public.handle_appointment_notification();

----------------------------------------------------------------------
-- RLS
----------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.procedures enable row level security;
alter table public.appointments enable row level security;
alter table public.notifications enable row level security;
alter table public.about_us enable row level security;
alter table public.clinic_locations enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;

drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone."
  on public.profiles for select using (true);

drop policy if exists "Users can insert own profile." on public.profiles;
create policy "Users can insert own profile."
  on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile."
  on public.profiles for update using (auth.uid() = id);

drop policy if exists "Admins can manage all profiles" on public.profiles;
create policy "Admins can manage all profiles"
  on public.profiles for all using (public.is_admin());

drop policy if exists "Users can view own conversations" on public.conversations;
create policy "Users can view own conversations"
  on public.conversations for select using (auth.uid() = user_id or auth.uid() = admin_id);

drop policy if exists "Users can update own conversations" on public.conversations;
create policy "Users can update own conversations"
  on public.conversations for update using (auth.uid() = user_id or auth.uid() = admin_id);

drop policy if exists "Users can create conversations" on public.conversations;
create policy "Users can create conversations"
  on public.conversations for insert with check (auth.uid() = user_id or auth.uid() = admin_id);

drop policy if exists "Users can view messages in own conversations" on public.messages;
create policy "Users can view messages in own conversations"
  on public.messages for select using (
    exists (
      select 1 from public.conversations
      where id = messages.conversation_id
        and (user_id = auth.uid() or admin_id = auth.uid())
    )
  );

drop policy if exists "Users can insert own messages" on public.messages;
create policy "Users can insert own messages"
  on public.messages for insert with check (auth.uid() = sender_id);

drop policy if exists "Admins can insert messages in their conversations" on public.messages;
create policy "Admins can insert messages in their conversations"
  on public.messages for insert with check (public.is_admin() and auth.uid() = sender_id);

drop policy if exists "Users can update messages in own conversations" on public.messages;
create policy "Users can update messages in own conversations"
  on public.messages for update using (
    exists (
      select 1 from public.conversations
      where id = messages.conversation_id
        and (user_id = auth.uid() or admin_id = auth.uid())
    )
  );

drop policy if exists "Procedures are viewable by everyone" on public.procedures;
create policy "Procedures are viewable by everyone"
  on public.procedures for select using (true);

drop policy if exists "Admins can manage procedures" on public.procedures;
create policy "Admins can manage procedures"
  on public.procedures for all using (public.is_admin());

drop policy if exists "Appointments viewable by owner or admin" on public.appointments;
create policy "Appointments viewable by owner or admin"
  on public.appointments for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "Appointments manageable by admin" on public.appointments;
create policy "Appointments manageable by admin"
  on public.appointments for all using (public.is_admin());

drop policy if exists "Users can create own appointments" on public.appointments;
create policy "Users can create own appointments"
  on public.appointments for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own appointments" on public.appointments;
create policy "Users can update own appointments"
  on public.appointments for update using (auth.uid() = user_id);

drop policy if exists "Notifications viewable by owner" on public.notifications;
create policy "Notifications viewable by owner"
  on public.notifications for select using (auth.uid() = user_id);

drop policy if exists "Notifications insertable by triggers" on public.notifications;
create policy "Notifications insertable by triggers"
  on public.notifications for insert with check (true);

drop policy if exists "Notifications manageable by owner" on public.notifications;
create policy "Notifications manageable by owner"
  on public.notifications for all using (auth.uid() = user_id);

drop policy if exists "About us viewable by everyone" on public.about_us;
create policy "About us viewable by everyone"
  on public.about_us for select using (true);

drop policy if exists "Admins can manage about us" on public.about_us;
create policy "Admins can manage about us"
  on public.about_us for all using (public.is_admin());

drop policy if exists "Clinic locations are viewable by everyone" on public.clinic_locations;
create policy "Clinic locations are viewable by everyone"
  on public.clinic_locations for select using (true);

drop policy if exists "Admins can manage clinic locations" on public.clinic_locations;
create policy "Admins can manage clinic locations"
  on public.clinic_locations for all using (public.is_admin());

drop policy if exists "Users can view own AI conversations" on public.ai_conversations;
create policy "Users can view own AI conversations"
  on public.ai_conversations for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "Users can create own AI conversations" on public.ai_conversations;
create policy "Users can create own AI conversations"
  on public.ai_conversations for insert with check (auth.uid() = user_id);

drop policy if exists "Admins can view all AI conversations" on public.ai_conversations;
create policy "Admins can view all AI conversations"
  on public.ai_conversations for select using (public.is_admin());

drop policy if exists "Admins can view all AI messages" on public.ai_messages;
create policy "Admins can view all AI messages"
  on public.ai_messages for select using (public.is_admin());

drop policy if exists "Users can manage own AI messages" on public.ai_messages;
create policy "Users can manage own AI messages"
  on public.ai_messages for all using (
    public.is_admin()
    or exists (
      select 1 from public.ai_conversations
      where ai_conversations.id = ai_messages.conversation_id
        and ai_conversations.user_id = auth.uid()
    )
  );

----------------------------------------------------------------------
-- Storage buckets and policies
----------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat_files',
  'chat_files',
  true,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic',
    'audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/wav', 'audio/webm',
    'audio/x-m4a',
    'video/mp4', 'video/quicktime',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile_photos',
  'profile_photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'procedure_images',
  'procedure_images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "chat_files: authenticated users can view" on storage.objects;
create policy "chat_files: authenticated users can view"
  on storage.objects for select
  using (bucket_id = 'chat_files' and auth.role() = 'authenticated');

drop policy if exists "chat_files: authenticated users can upload" on storage.objects;
create policy "chat_files: authenticated users can upload"
  on storage.objects for insert
  with check (bucket_id = 'chat_files' and auth.role() = 'authenticated');

drop policy if exists "chat_files: owners can update" on storage.objects;
create policy "chat_files: owners can update"
  on storage.objects for update
  using (bucket_id = 'chat_files' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "chat_files: owners or admins can delete" on storage.objects;
create policy "chat_files: owners or admins can delete"
  on storage.objects for delete
  using (
    bucket_id = 'chat_files'
    and (
      auth.uid()::text = (storage.foldername(name))[1]
      or public.is_admin()
    )
  );

drop policy if exists "profile_photos: public read" on storage.objects;
create policy "profile_photos: public read"
  on storage.objects for select
  using (bucket_id = 'profile_photos');

drop policy if exists "profile_photos: authenticated users can upload" on storage.objects;
create policy "profile_photos: authenticated users can upload"
  on storage.objects for insert
  with check (bucket_id = 'profile_photos' and auth.role() = 'authenticated');

drop policy if exists "profile_photos: owners or admins can update" on storage.objects;
create policy "profile_photos: owners or admins can update"
  on storage.objects for update
  using (
    bucket_id = 'profile_photos'
    and (
      auth.uid()::text = (storage.foldername(name))[1]
      or public.is_admin()
    )
  );

drop policy if exists "profile_photos: owners or admins can delete" on storage.objects;
create policy "profile_photos: owners or admins can delete"
  on storage.objects for delete
  using (
    bucket_id = 'profile_photos'
    and (
      auth.uid()::text = (storage.foldername(name))[1]
      or public.is_admin()
    )
  );

drop policy if exists "procedure_images: public read" on storage.objects;
create policy "procedure_images: public read"
  on storage.objects for select
  using (bucket_id = 'procedure_images');

drop policy if exists "procedure_images: admins can upload" on storage.objects;
create policy "procedure_images: admins can upload"
  on storage.objects for insert
  with check (bucket_id = 'procedure_images' and public.is_admin());

drop policy if exists "procedure_images: admins can update" on storage.objects;
create policy "procedure_images: admins can update"
  on storage.objects for update
  using (bucket_id = 'procedure_images' and public.is_admin());

drop policy if exists "procedure_images: admins can delete" on storage.objects;
create policy "procedure_images: admins can delete"
  on storage.objects for delete
  using (bucket_id = 'procedure_images' and public.is_admin());

----------------------------------------------------------------------
-- Realtime and schema cache refresh
----------------------------------------------------------------------
do $$
declare
  table_name text;
  table_names text[] := array[
    'profiles',
    'conversations',
    'messages',
    'procedures',
    'appointments',
    'notifications',
    'about_us',
    'clinic_locations',
    'ai_conversations',
    'ai_messages'
  ];
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array table_names loop
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      ) then
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      end if;
    end loop;
  end if;
end $$;

alter table public.messages replica identity full;
alter table public.ai_messages replica identity full;
alter table public.clinic_locations replica identity full;
alter table public.conversations replica identity full;
alter table public.notifications replica identity full;

-- Optional: after creating/signing in the real admin user, promote them:
-- update public.profiles set role = 'admin', status = 'active' where email = 'your-admin-email@example.com';

notify pgrst, 'reload schema';
