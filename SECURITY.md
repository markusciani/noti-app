# Security Policy

## Supported versions

The latest default branch is the actively supported line.

## Reporting a vulnerability

Please report security issues privately to the maintainers instead of opening a public issue.

Include:
- Affected area/file
- Reproduction steps
- Impact assessment
- Suggested mitigation (if available)

## Security expectations for contributors

- Never commit API secrets, private keys, or real credentials.
- Do not weaken Firestore/Storage rules to bypass permission errors.
- Enforce authorization server-side for all non-Firebase backends.
- Never trust client-provided admin/director claims without verification.
