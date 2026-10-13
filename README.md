# Noti

Noti is a Flutter app for church communication: announcements, director workflows, device registration, and push notifications.

## Screenshots

Current screenshot assets are in `/assets/images`. UI screenshots for docs are not yet checked in.

## Supported operating systems

- Android (primary production target)
- iOS
- macOS
- Windows
- Linux
- Web

## Backend providers

Firebase remains the default backend and push transport baseline.

| Provider | Status | Notes |
| --- | --- | --- |
| Firebase / Firestore | Fully supported | Default production path, existing Cloud Functions + FCM flow preserved. |
| Supabase / PostgreSQL | Experimental | Secure HTTP adapter implemented; requires backend endpoints and policy setup. |
| Convex | Experimental | Secure HTTP adapter implemented; requires server-side Convex actions/functions. |
| PostgreSQL via secure API | Planned | Use `postgres_api` provider with your own secured API. |
| MySQL via secure API | Planned | Use `mysql_api` provider with your own secured API. |
| MongoDB via secure API | Planned | Use `mongodb_api` provider with your own secured API. |
| Custom REST API | Experimental | Generic adapter available for documented announcement endpoints. |

> Noti clients must never connect directly to privileged databases. Use provider auth + secured backend APIs.

## Installation

1. Clone the repository.
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. (Optional) Install Firebase Functions dependencies:
   ```bash
   cd functions && npm install
   ```

## Configuration

Copy `.env.example` values into your build pipeline or pass as `--dart-define` flags.

### Backend provider selection

```bash
flutter run \
  --dart-define=NOTI_BACKEND_PROVIDER=firebase
```

Supported values: `firebase`, `supabase`, `convex`, `postgres_api`, `mysql_api`, `mongodb_api`, `custom_api`.

### Firebase setup (default)

1. Configure Firebase for each platform (`lib/firebase_options.dart`).
2. Enable Firebase Authentication providers used by your deployment.
3. Deploy rules and functions:
   ```bash
   firebase deploy --only firestore:rules,functions
   ```
4. Keep FCM enabled for push delivery.

### Supabase setup

Provide:
- `NOTI_BACKEND_PROVIDER=supabase`
- `NOTI_SUPABASE_URL`
- `NOTI_SUPABASE_ANON_KEY`
- Optional `NOTI_BACKEND_API_BASE_URL` if using a dedicated gateway.

Implement secured announcement endpoints in Supabase Edge Functions and enforce organization permissions server-side.

### Convex setup

Provide:
- `NOTI_BACKEND_PROVIDER=convex`
- `NOTI_CONVEX_URL`

Expose secured HTTP actions/functions for announcements and enforce token verification/tenant isolation.

### Custom backend setup

Provide:
- `NOTI_BACKEND_PROVIDER=custom_api` (or `postgres_api`, `mysql_api`, `mongodb_api`)
- `NOTI_CUSTOM_API_URL` or `NOTI_BACKEND_API_BASE_URL`

Expected announcement endpoints:
- `GET /announcements?organizationId=...`
- `POST /announcements`
- `PATCH /announcements/{id}`
- `DELETE /announcements/{id}`

Use bearer-token auth and server-side authorization.

## Authentication configuration

- Firebase remains active in default mode.
- Alternative providers must verify tokens on the server.
- Never trust client-provided roles.
- Tenant/org access must be enforced by backend policy/rules.

## Push notification setup

- FCM is retained as the default notification transport.
- Database provider selection does **not** disable push delivery automatically.
- For non-FCM platforms, implement a secure transport bridge in backend APIs and keep permission checks server-side.

## Local development

```bash
flutter run
```

Recommended before PR:
```bash
flutter analyze
flutter test
```

## Testing

Current repository tests include theme tests and backend provider selection tests.

Run all tests:
```bash
flutter test
```

## Troubleshooting

- **No announcements with alternative provider**: verify backend URL and endpoint auth headers.
- **Permission errors**: verify role mapping and org isolation policy in your backend.
- **Push not arriving**: verify FCM token registration and topic subscriptions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security reporting

See [SECURITY.md](SECURITY.md).

## Open-source readiness documents

- [docs/backend_architecture.md](docs/backend_architecture.md)
- [docs/development_setup.md](docs/development_setup.md)
- [docs/firebase_dependency_audit.md](docs/firebase_dependency_audit.md)
- [docs/repository_audit.md](docs/repository_audit.md)
- [LICENSE_PROPOSAL.md](LICENSE_PROPOSAL.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [AGENTS.md](AGENTS.md)
