# ChatApp — WhatsApp-like Flutter chat app

A WhatsApp-style chat app built with Flutter, backed by a self-hosted
Supabase instance. Green WhatsApp-style theme (`#075E54` / `#25D366`),
tabs for Chats / Updates / Calls, message bubbles with read ticks.

## What works (v1)

- **Login / Register with username + password ONLY — confirmed requirement.**
  The signup screen asks for username and password only: no email field,
  no phone field, no extra step. After tapping Sign Up the user goes
  straight into the app (chats list) — no email-verification screen and
  no "check your inbox" blocker. In code (`lib/services/auth_service.dart`)
  the username is mapped to a Supabase Auth account behind the scenes
  (derived email `username@chat.local`, never shown to the user). If
  Supabase returns a user with no session because email confirmation is
  on, the app immediately signs the user in with the same
  username/password, and only shows a clear in-app error if that fails.
  Usernames are unique: the app checks `profiles` before signup and
  shows **"username already taken"** if so (the `profiles.username`
  unique constraint is a second guard). Login uses the exact same
  username + password fields.
- **1-1 chats:** search users by username, start a chat, send/receive
  text messages live via Supabase Realtime, timestamps, read ticks
  (✓ sent, ✓✓ delivered, blue ✓✓ read).
- **Group chats:** create a group with several members. Groups use the
  same `chats` / `chat_members` / `messages` model as 1-1 chats — they
  are not local-only.
- **Status / Updates:** post a text status, view other users' statuses
  from the last 24 hours.
- **Media:** attach an image from the gallery; it uploads to the
  Supabase Storage bucket `chat-media` and is sent as an image message.
  If the bucket does not exist yet, the app shows a clear error instead
  of sending a fake image message.
- **Profile / Settings:** shows your username, sign out.

## What does NOT work yet (honest)

- **Real voice/video calls are NOT implemented.** The Calls tab and the
  call screen are UI placeholders (labelled as such in the app). The
  call log on the Calls tab is local to the device.
- **No end-to-end encryption.** Messages are protected by Supabase Row
  Level Security (only chat members can read a chat), but they are not
  E2E-encrypted like WhatsApp.
- No push notifications, no contact sync from the phone book, no
  message replies/reactions/forwards, no voice messages yet.

## Setup — exact steps

1. **Run the database script once.** In your Supabase dashboard, open
   SQL Editor and run the whole `supabase_schema.sql` in this repo root.
   It creates `profiles`, `chats`, `chat_members`, `messages`,
   `statuses`, their RLS policies, Realtime for messages/statuses, and
   the `chat-media` storage bucket.
2. **Server note: on this self-hosted Supabase, Auth > Email confirmation
   should be OFF (or signup will be blocked)** — but the app itself must
   not depend on the user doing email verification (see "What works").
3. **Storage (if step 1's bucket insert did not apply):** Dashboard >
   Storage > New bucket, name `chat-media`, Public ON. Without it, image
   upload shows an error and text chat still works.
4. **App config is already set** in `lib/config.dart`:
   Supabase URL `https://supabase.adoetz52.my.id` and the publishable
   anon key. Never put a `service_role` key in the app — it bypasses
   RLS and must never ship in an APK.

## Build locally

```sh
flutter pub get
flutter run
# or: flutter build apk --release
# APK output: build/app/outputs/flutter-apk/app-release.apk
```

Requires Flutter stable and Android SDK (Java 17).

## Build via GitHub Actions

Push this repo to GitHub. The workflow in
`.github/workflows/android.yml` runs `flutter build apk --release`
and uploads the APK as a build artifact named `app-release-apk`.
Download it from the Actions run's Artifacts section.

## Project layout

```
lib/
  main.dart                  App entry, Supabase init, AuthGate
  config.dart                Supabase URL + anon key (publishable only)
  models.dart                Profile / ChatSummary / ChatMessage / StatusItem
  services/
    auth_service.dart        Username+password auth, username-taken check,
                             immediate sign-in after signup
    chat_service.dart        Chats, groups, messages, statuses, media upload
  screens/
    auth_screen.dart         Login/Register — username + password only
    home_screen.dart         Chats / Updates / Calls tabs
    chat_screen.dart         Message thread, bubbles, image attach
    new_chat_screen.dart     Search users, 1-1 chat, create group
    status_tab.dart          Post / view text statuses
    calls_tab.dart           Demo call log UI
    call_screen.dart         Placeholder call screen (no real calls)
    settings_screen.dart     Profile + sign out
  widgets/
    message_bubble.dart      WhatsApp-style bubble + read ticks
android/                     applicationId com.abdurahman.whatsappclone,
                             minSdk 23, INTERNET permission added to the
                             main manifest (release builds need it for Supabase)
supabase_schema.sql          Run once in Supabase SQL Editor
```

## Database tables

| Table | Key columns |
|---|---|
| `profiles` | `id` (uuid, FK auth.users), `username` (unique), `display_name`, `avatar_url`, `created_at` |
| `chats` | `id`, `name` (group name, null for 1-1), `is_group`, `created_by`, `created_at` |
| `chat_members` | `chat_id`, `user_id` (composite PK) |
| `messages` | `id`, `chat_id`, `sender_id`, `body`, `image_url`, `is_read`, `created_at` |
| `statuses` | `id`, `user_id`, `text`, `created_at` |
| Storage | bucket `chat-media`, files at `<user-id>/<timestamp>.<ext>` |
