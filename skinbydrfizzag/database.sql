-- 1. Clean up existing objects (allows re-running the script)
drop table if exists public.about_us cascade;
drop table if exists public.notifications cascade;
drop table if exists public.appointments cascade;
drop table if exists public.procedures cascade;
drop table if exists public.messages cascade;
drop table if exists public.conversations cascade;
drop table if exists public.profiles cascade;

-- enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

----------------------------------------------------------------------
-- helper function for updated_at timestamp
----------------------------------------------------------------------
create or replace function trigger_set_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

----------------------------------------------------------------------
-- profiles table referencing auth.users
----------------------------------------------------------------------
create table public.profiles (
  id uuid primary key, -- Note: Handled by backend/auth triggers
  full_name text,
  email text,
  phone text,
  role text not null default 'user',        -- 'admin' or 'user'
  photo_url text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.profiles
  add constraint profiles_role_check check (role in ('admin','user'));

create index on public.profiles (role);
create index on public.profiles (email);

-- trigger for profiles
create trigger profiles_set_timestamp
  before update on public.profiles
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- conversations table
----------------------------------------------------------------------
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  admin_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null default 'app', -- 'app' or 'whatsapp'
  last_message text,
  last_sender_id uuid,
  unread_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index on public.conversations (user_id);
create index on public.conversations (admin_id);
create index on public.conversations (updated_at);
create index if not exists conversations_platform_idx on public.conversations (platform);

create trigger conversations_set_timestamp
  before update on public.conversations
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- messages table
----------------------------------------------------------------------
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  sender_name text,
  sender_role text not null default 'user',
  message_type text not null default 'text',
  text text not null,
  is_read boolean not null default false,
  platform text not null default 'app', -- 'app' or 'whatsapp'
  whatsapp_message_id text, -- ID from Meta WhatsApp API
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index on public.messages (conversation_id);
create index on public.messages (sender_id);
create index on public.messages (created_at);

create trigger messages_set_timestamp
  before update on public.messages
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- procedures table
----------------------------------------------------------------------
create table public.procedures (
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

create index on public.procedures (title);

create trigger procedures_set_timestamp
  before update on public.procedures
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- appointments table
----------------------------------------------------------------------
create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  procedure_id uuid references public.procedures(id) on delete set null,
  scheduled_at timestamptz not null,
  status text not null default 'pending',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index on public.appointments (user_id);
create index on public.appointments (procedure_id);
create index on public.appointments (scheduled_at);
create index on public.appointments (status);

create trigger appointments_set_timestamp
  before update on public.appointments
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- notifications table
----------------------------------------------------------------------
create table public.notifications (
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

create index on public.notifications (user_id);
create index on public.notifications (is_read);

create trigger notifications_set_timestamp
  before update on public.notifications
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- about_us table
----------------------------------------------------------------------
create table public.about_us (
  id serial primary key,
  description text,
  email text,
  phone text,
  instagram_url text,
  facebook_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Insert initial empty record if not exists
insert into public.about_us (id, description) values (1, 'Clinic Information') 
on conflict (id) do update set description = excluded.description;

create trigger about_us_set_timestamp
  before update on public.about_us
  for each row execute function trigger_set_timestamp();

----------------------------------------------------------------------
-- IMPORTANT: Ensure Admin Profile Exists (Required for WhatsApp Backend)
----------------------------------------------------------------------
-- This admin profile is used by the Flask backend for WhatsApp conversations
-- The ADMIN_ID must match the backend .env ADMIN_ID environment variable
-- UUID: b3c2332c-cfa7-48b5-bf27-d57460efb1ac
insert into public.profiles (
  id,
  full_name,
  email,
  phone,
  role,
  status,
  created_at,
  updated_at
) values (
  'b3c2332c-cfa7-48b5-bf27-d57460efb1ac',
  'Talha',
  'talha@mail.com',
  '923017441892',
  'admin',
  'active',
  now(),
  now()
)
on conflict (id) do update set
  role = 'admin',
  status = 'active',
  updated_at = now();

----------------------------------------------------------------------
-- Profile creation trigger (Run this in Supabase SQL Editor)
----------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, phone, role)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'phone',
    'user'
  );
  return new;
end;
$$ language plpgsql security definer;

-- Remove existing trigger if any, then create it
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

----------------------------------------------------------------------
-- Row Level Security enablement
----------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.procedures enable row level security;
alter table public.appointments enable row level security;
alter table public.notifications enable row level security;
alter table public.about_us enable row level security;
-- AI chat tables
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
  sender text not null, -- 'user' or 'ai'
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_conversations_user_id_idx on public.ai_conversations (user_id);
create index if not exists ai_messages_conversation_id_idx on public.ai_messages (conversation_id);

alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;

----------------------------------------------------------------------
-- HELPER FUNCTIONS FOR RLS
----------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid()
    and role = 'admin'
  );
end;
$$ language plpgsql security definer;

----------------------------------------------------------------------
-- TRIGGERS FOR AUTOMATION
----------------------------------------------------------------------

-- 1. Update conversation metadata and unread count on new message
create or replace function public.handle_new_message_logic()
returns trigger as $$
begin
  -- Update conversation record
  update public.conversations
  set 
    last_message = new.text,
    last_sender_id = new.sender_id,
    unread_count = unread_count + 1,
    updated_at = now()
  where id = new.conversation_id;

  -- Create notification for recipient
  insert into public.notifications (user_id, title, message, type, conversation_id)
  select 
    case when user_id = new.sender_id then admin_id else user_id end,
    case when new.sender_role = 'admin' then 'New Message from Doctor' else 'New Message' end,
    new.text,
    'message',
    new.conversation_id
  from public.conversations
  where id = new.conversation_id;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_new_message on public.messages;
create trigger on_new_message
  after insert on public.messages
  for each row execute function public.handle_new_message_logic();

-- 2. Create notifications for appointment changes
create or replace function public.handle_appointment_notification()
returns trigger as $$
declare
  proc_title text;
begin
  select title into proc_title from procedures where id = new.procedure_id;

  if (tg_op = 'INSERT') then
    insert into public.notifications (user_id, title, message, type, appointment_id)
    values (new.user_id, 'New Appointment', 'Your appointment for ' || coalesce(proc_title, 'Procedure') || ' has been booked.', 'appointment', new.id);
  elsif (tg_op = 'UPDATE' and old.status <> new.status) then
    insert into public.notifications (user_id, title, message, type, appointment_id)
    values (new.user_id, 'Appointment Updated', 'Your appointment for ' || coalesce(proc_title, 'Procedure') || ' is now ' || new.status || '.', 'appointment', new.id);
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_appointment_change on public.appointments;
create trigger on_appointment_change
  after insert or update on public.appointments
  for each row execute function public.handle_appointment_notification();

----------------------------------------------------------------------
-- IMPROVED RLS POLICIES
----------------------------------------------------------------------

-- Profiles
create policy "Public profiles are viewable by everyone." on profiles for select using ( true );
-- IMPORTANT: Don't allow admins to update id field to prevent changing admin ID
create policy "Admins can manage all profiles" on profiles for all using ( is_admin() );
-- When admin updates a profile, prevent changing the id field
create policy "Profile id field cannot be changed" on profiles for update using ( 
  (auth.uid() = id) or (is_admin() and auth.uid() <> id)
);
create policy "Users can update own profile." on profiles for update using ( auth.uid() = id );
create policy "Users can insert own profile." on profiles for insert with check ( auth.uid() = id );

-- Conversations  
-- Users and admins can only read/update their own conversations
create policy "Users can view own conversations" on conversations for select using ( auth.uid() = user_id or auth.uid() = admin_id );
create policy "Users can update own conversations" on conversations for update using ( auth.uid() = user_id or auth.uid() = admin_id );
create policy "Users can create conversations" on conversations for insert with check ( auth.uid() = user_id or auth.uid() = admin_id );
-- Backend service role bypasses RLS for creating WhatsApp conversations from webhook

-- Messages
create policy "Users can view messages in own conversations" on messages for select using ( 
  exists (select 1 from conversations where id = messages.conversation_id and (user_id = auth.uid() or admin_id = auth.uid())) 
);
create policy "Users can insert own messages" on messages for insert with check ( auth.uid() = sender_id );
-- Allow admins to insert messages (when they're the sender)
create policy "Admins can insert messages in their conversations" on messages for insert with check ( 
  is_admin() and auth.uid() = sender_id 
);
-- Allow message updates (e.g., for is_read status)
create policy "Users can update messages in own conversations" on messages for update using (
  exists (select 1 from conversations where id = messages.conversation_id and (user_id = auth.uid() or admin_id = auth.uid()))
);

-- Procedures
create policy "Procedures are viewable by everyone" on procedures for select using ( true );
create policy "Admins can manage procedures" on procedures for all using ( is_admin() );

-- Appointments
create policy "Appointments viewable by owner or admin" on appointments for select using ( auth.uid() = user_id or is_admin() );
create policy "Appointments manageable by admin" on appointments for all using ( is_admin() );
create policy "Users can create own appointments" on appointments for insert with check ( auth.uid() = user_id );
create policy "Users can update own appointments" on appointments for update using ( auth.uid() = user_id );

-- Notifications
create policy "Notifications viewable by owner" on notifications for select using ( auth.uid() = user_id );
create policy "Notifications insertable by triggers" on notifications for insert with check ( true ); 
create policy "Notifications manageable by owner" on notifications for all using ( auth.uid() = user_id );

-- AI conversations/messages (user owns their AI chats)
drop policy if exists "Users can view own AI conversations" on ai_conversations;
drop policy if exists "Users can create own AI conversations" on ai_conversations;
drop policy if exists "Users can view own AI messages" on ai_messages;
drop policy if exists "Users can insert own AI user messages" on ai_messages;
drop policy if exists "Users can manage own AI messages" on ai_messages;

-- Allow users to see their AI chats
create policy "Users can view own AI conversations"
  on ai_conversations for select using ( auth.uid() = user_id );

create policy "Users can create own AI conversations"
  on ai_conversations for insert with check ( auth.uid() = user_id );

-- IMPORTANT: Backend uses Service Role Key, so it bypasses RLS. 
-- But Flutter app might try to insert. Let's allow users to insert messages where they are the owner of the conversation.
create policy "Users can manage own AI messages"
  on ai_messages for all using (
    exists (
      select 1 from ai_conversations
      where ai_conversations.id = ai_messages.conversation_id
      and ai_conversations.user_id = auth.uid()
    )
  );

-- About Us
create policy "About us viewable by everyone" on about_us for select using ( true );
create policy "Admins can manage about us" on about_us for all using ( is_admin() );

----------------------------------------------------------------------
-- REALTIME SUBSCRIPTION
----------------------------------------------------------------------
-- Enable realtime for ALL relevant tables
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    -- Add profiles
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'profiles') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    END IF;
    -- Add conversations
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'conversations') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;
    -- Add messages
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;
    -- Add appointments
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'appointments') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.appointments;
    END IF;
    -- Add notifications
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
    -- Add procedures
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'procedures') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.procedures;
    END IF;
    -- Add about_us
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'about_us') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.about_us;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'ai_conversations') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_conversations;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'ai_messages') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_messages;
    END IF;
  END IF;
END $$;

-- Enable Realtime for specific columns (optional but good practice)
alter table public.messages replica identity full;
alter table public.ai_messages replica identity full;

-- Update the handle_new_user function to be more robust
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

-- Trigger to update unread count on conversation ONLY if sender is not current recipient
create or replace function public.increment_unread_count()
returns trigger as $$
begin
  update public.conversations
  set unread_count = unread_count + 1,
      updated_at = now(),
      last_message = new.text,
      last_sender_id = new.sender_id
  where id = new.conversation_id;
  return new;
end;
$$ language plpgsql security definer;

-- 1. First, make sure every existing user has a profile record (Repairs missing profiles)
INSERT INTO public.profiles (id, full_name, email, role)
SELECT id, raw_user_meta_data->>'full_name', email, 'user'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 2. NOW, set Talha as the Admin (the admin user)
UPDATE public.profiles 
SET role = 'admin' 
WHERE email = 'talha@mail.com';

-- 3. Verify admin is set up
SELECT email, role, full_name FROM public.profiles WHERE role = 'admin';

-- 1. Add column to store file/audio URL in messages
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS file_url TEXT;

-- 2. Add column to store FCM tokens for push notifications in profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 3. Update the message trigger to handle notification body for non-text messages
CREATE OR REPLACE FUNCTION public.handle_new_message_logic()
RETURNS trigger AS $$
DECLARE
  notif_message text;
BEGIN
  -- Determine notification body
  IF (new.message_type = 'text') THEN
    notif_message := new.text;
  ELSIF (new.message_type = 'image') THEN
    notif_message := '📷 Sent an image';
  ELSIF (new.message_type = 'voice' OR new.message_type = 'audio') THEN
    notif_message := '🎤 Sent a voice message';
  ELSE
    notif_message := '📎 Sent a file';
  END IF;

  -- Update conversation record
  UPDATE public.conversations
  SET 
    last_message = notif_message,
    last_sender_id = new.sender_id,
    unread_count = unread_count + 1,
    updated_at = now()
  WHERE id = new.conversation_id;

  -- Create internal notification for recipient
  INSERT INTO public.notifications (user_id, title, message, type, conversation_id)
  SELECT 
    CASE WHEN user_id = new.sender_id THEN admin_id ELSE user_id END,
    CASE WHEN new.sender_role = 'admin' THEN 'New Message from Doctor' ELSE 'New Message from User' END,
    notif_message,
    'message',
    new.conversation_id
  FROM public.conversations
  WHERE id = new.conversation_id;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
