# Backend Architecture

## Goals

- Keep Firebase/Firestore as default backend.
- Allow alternative providers via shared contracts.
- Keep push notification delivery decoupled from database choice.

## Structure

- `lib/core/backend/backend_config.dart`
- `lib/core/backend/backend_provider.dart`
- `lib/core/backend/backend_factory.dart`
- `lib/core/backend/interfaces/*`
- `lib/data/providers/firebase/*`
- `lib/data/providers/supabase/*`
- `lib/data/providers/convex/*`
- `lib/data/providers/custom_api/*`

## Contracts

Interfaces currently cover:

- Authentication
- User profiles
- Organizations
- Devices
- Notifications (announcement CRUD + stream)
- Notification delivery transport
- Realtime updates (contract in place)
- File storage (contract in place)

## Provider selection

`NOTI_BACKEND_PROVIDER` controls backend selection. Default is Firebase.

## Security model

- Clients authenticate and forward bearer tokens only.
- Backend APIs must verify tokens and enforce organization-role permissions.
- Admin/director roles must be validated server-side.
- No direct privileged DB credentials on Flutter clients.

## Current implementation state

- Announcement repository is wired through backend factory.
- Firebase provider preserves existing callable + Firestore behavior.
- Supabase/Convex/Custom API adapters use secure HTTP endpoint contracts.
- PostgreSQL/MySQL/MongoDB are expected to run through secure APIs using the same adapter pattern.
