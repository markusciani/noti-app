# Development Setup

## 1) Clone

```bash
git clone https://github.com/markusciani/noti-app.git
cd noti-app
```

## 2) Install dependencies

```bash
flutter pub get
```

## 3) Select backend provider

Choose one via `--dart-define`:

```bash
--dart-define=NOTI_BACKEND_PROVIDER=firebase
```

## 4) Configure authentication

- Firebase default: configure Firebase Auth + Firestore rules.
- Other providers: configure server-side token verification and role/org enforcement.

## 5) Configure notifications

- Keep FCM enabled for default transport.
- If using another transport, implement secure backend delivery and set `NOTI_NOTIFICATION_TRANSPORT`.

## 6) Run app

```bash
flutter run
```

## 7) Test integration

```bash
flutter analyze
flutter test
```

## 8) Build

```bash
flutter build appbundle --release
```

Use your own cloud projects, credentials, and deployment environments.
