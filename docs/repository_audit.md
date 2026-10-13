# Repository Audit Notes

## Checked areas

- Build/generated artifacts
- Temporary files
- Credentials/secrets exposure risks
- Documentation consistency

## Findings

1. `functions/node_modules` exists in the repository tree and should not be required in source control for normal open-source workflows.
2. Root `.gitignore` did not explicitly ignore `functions/node_modules`.
3. Existing docs were release-focused and missing contributor/security/open-source onboarding details.

## Actions in this change

- Added backend and OSS docs (`README`, `CONTRIBUTING`, `SECURITY`, `CODE_OF_CONDUCT`, `AGENTS`, architecture/audit docs).
- Added `.env.example` placeholders (no production secrets).
- Updated `.gitignore` to include function dependency/build output patterns.

## Follow-up recommendations

- Remove tracked `functions/node_modules` in a dedicated cleanup PR after maintainers confirm deployment workflow.
- Rotate credentials immediately if any private key is ever discovered in commit history (history rewrite may be required).
