# AGENTS

This repository contains a Flutter client and Firebase Functions backend for Noti.

## Purpose

Enable secure announcements and notification workflows while keeping Firebase as the default backend and allowing incremental backend-provider expansion.

## Agent guidance

- Prefer provider interfaces under `lib/core/backend/interfaces`.
- Keep `firebase` as the default provider path.
- Treat push delivery as a separate concern from data persistence.
- Do not introduce direct client-to-database privileged access.
- Preserve current UI/UX behavior unless explicitly requested.
