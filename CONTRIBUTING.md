# Contributing to Noti

## Development workflow

1. Fork/branch from the latest default branch.
2. Keep changes scoped and incremental.
3. Run before opening a PR:
   ```bash
   flutter analyze
   flutter test
   ```
4. Update docs when behavior/configuration changes.

## Code guidelines

- Preserve existing functionality and UI unless a change is explicitly requested.
- Keep Firebase compatibility intact.
- Never commit secrets, credentials, or production data.
- Keep backend integrations behind documented interfaces.

## Backend changes

- Keep `firebase` as default provider.
- For non-Firebase providers, use secure backend APIs.
- Do not add direct mobile-client access to privileged databases.

## Pull requests

Include:
- What changed
- Why it changed
- How it was tested
- Any incomplete or planned follow-up work
