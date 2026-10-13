# Firebase Dependency Audit

## Flutter dependencies

- `firebase_core`: app bootstrap
- `cloud_firestore`: data reads/writes for announcements, devices, settings, organizations
- `firebase_auth`: anonymous + staff authentication identity
- `firebase_messaging`: FCM token/device push transport
- `cloud_functions`: server-authoritative actions (announcement/device/org/role workflows)
- `firebase_storage`: profile image uploads

## Backend dependencies (`functions/package.json`)

- `firebase-admin`
- `firebase-functions`

## Firestore/Storage rule posture

- Firestore rules restrict privileged writes to server functions and director role checks.
- Storage rules allow user-scoped profile image uploads and deny all other paths.

## Role usage findings

- App and rules now center on `director` role.
- Legacy `admin`/`founder` values still appear in Cloud Functions migration paths.
- Current server checks normalize these legacy roles to `director` in authorization helpers.

## Migration recommendation

Keep role normalization while planning explicit migration and test coverage for any future role model changes.
