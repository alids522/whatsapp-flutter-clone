-- ============================================================
-- WhatsApp-like Flutter chat app — Supabase schema (v1)
-- Run this ONCE in the Supabase SQL Editor (Dashboard > SQL Editor).
-- The app's anon key cannot create tables, so this step is required
-- before the APK can log in / chat.
--
-- Server note (one line): on this self-hosted Supabase, Auth >
-- Email confirmation should be OFF, otherwise signup will be blocked.
-- The app itself does not depend on email verification: after signup
-- it signs the user in immediately with the same username/password,
-- and only shows an error if that sign-in fails.
-- ============================================================

-- ---------- profiles ----------
-- One row per user. username is the login name (lower-cased by the app).
-- The app maps username -> derived email username@chat.local for
-- Supabase Auth; the user only ever sees username + password.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- ---------- chats ----------
create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  name text,
  is_group boolean not null default false,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ---------- chat_members ----------
create table if not exists public.chat_members (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

-- ---------- messages ----------
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  body text,
  image_url text,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint messages_body_or_image check (body is not null or image_url is not null)
);

-- ---------- statuses (Updates tab, last 24h shown by the app) ----------
create table if not exists public.statuses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.profiles enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.statuses enable row level security;

-- profiles: anyone (anon included) can read usernames — this is what
-- makes the pre-signup "username already taken" check and the
-- in-app user search work. Profiles hold no secrets.
drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public" on public.profiles
  for select to anon, authenticated using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

-- chats: readable by members, creatable by any signed-in user.
drop policy if exists "chats_select_member" on public.chats;
create policy "chats_select_member" on public.chats
  for select to authenticated using (
    exists (
      select 1 from public.chat_members
      where chat_members.chat_id = chats.id
        and chat_members.user_id = auth.uid()
    )
  );

drop policy if exists "chats_insert_auth" on public.chats;
create policy "chats_insert_auth" on public.chats
  for insert to authenticated with check (true);

-- chat_members: readable by members (or for your own rows),
-- insertable by the chat creator or for yourself.
drop policy if exists "chat_members_select" on public.chat_members;
create policy "chat_members_select" on public.chat_members
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.chat_members m
      where m.chat_id = chat_members.chat_id
        and m.user_id = auth.uid()
    )
  );

drop policy if exists "chat_members_insert" on public.chat_members;
create policy "chat_members_insert" on public.chat_members
  for insert to authenticated with check (
    user_id = auth.uid()
    or exists (
      select 1 from public.chats
      where chats.id = chat_id and chats.created_by = auth.uid()
    )
  );

-- messages: readable / updatable (mark-as-read) by chat members,
-- insertable only as yourself and only into chats you belong to.
drop policy if exists "messages_select_member" on public.messages;
create policy "messages_select_member" on public.messages
  for select to authenticated using (
    exists (
      select 1 from public.chat_members
      where chat_members.chat_id = messages.chat_id
        and chat_members.user_id = auth.uid()
    )
  );

drop policy if exists "messages_insert_member" on public.messages;
create policy "messages_insert_member" on public.messages
  for insert to authenticated with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.chat_members
      where chat_members.chat_id = messages.chat_id
        and chat_members.user_id = auth.uid()
    )
  );

drop policy if exists "messages_update_member" on public.messages;
create policy "messages_update_member" on public.messages
  for update to authenticated using (
    exists (
      select 1 from public.chat_members
      where chat_members.chat_id = messages.chat_id
        and chat_members.user_id = auth.uid()
    )
  );

-- statuses: readable by any signed-in user, writable only by owner.
drop policy if exists "statuses_select_auth" on public.statuses;
create policy "statuses_select_auth" on public.statuses
  for select to authenticated using (true);

drop policy if exists "statuses_insert_own" on public.statuses;
create policy "statuses_insert_own" on public.statuses
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "statuses_delete_own" on public.statuses;
create policy "statuses_delete_own" on public.statuses
  for delete to authenticated using (user_id = auth.uid());

-- ============================================================
-- Realtime: messages (and statuses) must be in the publication
-- for the app's Realtime stream to receive new rows.
-- ============================================================
do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then
    null;
  end;
  begin
    alter publication supabase_realtime add table public.statuses;
  exception when duplicate_object then
    null;
  end;
end $$;

-- ============================================================
-- Storage bucket for chat images (optional but recommended).
-- If this insert fails on your setup, create the bucket manually:
-- Dashboard > Storage > New bucket, name "chat-media", Public ON.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', true)
on conflict (id) do nothing;

drop policy if exists "chat_media_read" on storage.objects;
create policy "chat_media_read" on storage.objects
  for select to authenticated, anon
  using (bucket_id = 'chat-media');

drop policy if exists "chat_media_upload_own_folder" on storage.objects;
create policy "chat_media_upload_own_folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
