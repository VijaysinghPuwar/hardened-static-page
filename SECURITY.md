# Security

## Reporting

Open a private security advisory through the repository's Security tab, or
email vpuwar199@gmail.com. I will acknowledge within a few days.

This is a static page with no server, no database, no authentication and no
user input, so the realistic attack surface is the supply chain and the
response headers rather than the application.

## What is enforced

Every one of these is checked by CI on each push, and the build fails if any
of them regresses.

| control | where |
|---|---|
| `default-src 'none'` CSP, no `unsafe-inline` | `_headers` |
| CSP proven to block inline script, not just present | `headers` job |
| HSTS, COOP/COEP/CORP, `nosniff`, `no-referrer` | `_headers` |
| `Permissions-Policy` denying all 18 unused features | `_headers` |
| Secret scanning over full git history | `secrets` job |
| GitHub Actions pinned to commit SHAs, not tags | `ci.yml` |
| gitleaks download verified by SHA-256 | `secrets` job |
| Page weight budget | `budget` job |

## Notes

The page ships no JavaScript. If that ever changes, `script-src` has to be
added to the policy deliberately - it is currently covered by `default-src
'none'`, so any script would be blocked rather than silently allowed.

The font is self-hosted rather than loaded from Google Fonts. That is what
makes `style-src 'self'` possible: the Google Fonts stylesheet is generated
per user-agent and so can never be subresource-integrity pinned.
