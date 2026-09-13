# hardened-static-page

A static page with a deny-by-default Content-Security-Policy, a page weight
budget, and CI that fails the build when either regresses.

The page itself is deliberately trivial — one screen, three cards, no
framework. The engineering around it is the point.

## Measured

Numbers below come from the Lighthouse run in CI, not from estimates.

| | |
|---|---|
| Lighthouse — performance / a11y / best practices / SEO | 100 / 100 / 100 / 100 |
| Cold load | 34 KB |
| Largest Contentful Paint | 0.3 s |
| Cumulative Layout Shift | 0 |
| JavaScript shipped | none |
| Third-party requests | none |

## Content-Security-Policy

The page has no JavaScript, no inline style, no forms and no frames, so the
policy denies by default and allows only the four things it actually loads:

```
default-src 'none'; style-src 'self'; img-src 'self'; font-src 'self';
base-uri 'none'; form-action 'none'; frame-ancestors 'none'
```

No `unsafe-inline`, no `unsafe-eval`. That is only reachable because the font
is self-hosted — the Google Fonts stylesheet is generated per user-agent, so
it can never be SRI-pinned or covered by `style-src 'self'`. The font decision
and the CSP strength are the same decision.

Alongside it: HSTS (2 years, preload), `nosniff`, `no-referrer`,
COOP/COEP/CORP, and a `Permissions-Policy` that turns off all 18 features the
page does not use. `_headers` is read directly by Cloudflare Pages and
Netlify.

## CI

Five jobs, all of which can fail the build.

| job | what it checks |
|---|---|
| `lint` | html-validate (recommended + a11y), stylelint |
| `budget` | critical path ≤ 150 KB, any single file ≤ 200 KB, tracked tree ≤ 1 MB |
| `headers` | every security header present, **and** that an injected inline script is actually blocked |
| `secrets` | gitleaks across full history |
| `lighthouse` | performance, a11y, best-practices and byte-weight assertions |

The `headers` job is worth a note: asserting that a header string is present
proves very little. It also injects an inline `<script>` into a copy of the
page and fails if it executes, so the policy is tested for effect rather than
for spelling.

## Deploying

The host has to be one that serves the `_headers` file, or the whole policy
above is dead config. Cloudflare Pages and Netlify both do; GitHub Pages does
not.

On Cloudflare Pages, with no build step:

| setting | value |
|---|---|
| Framework preset | None |
| Build command | *(leave empty)* |
| Build output directory | `/` |

Then point CI at it so the deployed headers are verified on every push, not
just the local ones:

```sh
gh variable set SITE_URL --body https://<project>.pages.dev
```

Until that variable is set the `live` job skips.

## How it got here

This started as a fan page with a 19 MB image in it. Each number below is the
result of one commit in the history.

| | before | after |
|---|---|---|
| hero artwork | 19,523,366 B PNG | 1,020 B SVG |
| cold page load | ~19.6 MB | 34 KB |
| third-party hosts | 3 | 0 |
| security headers | none | 9 |
| git clone | 6.58 MiB | 502 KiB |

The budget check in CI exists specifically because nothing stopped that 19 MB
file the first time.

## Running it

```sh
npm ci
npm test               # lint + weight budget
npm run serve          # serves on :8000 with the production headers applied
npm run check:headers  # asserts them against the running server
./tools/build-images.sh  # regenerates favicons and the OG card from the SVG
```

`tools/serve.py` parses `_headers` and applies the same rules the host will,
so the policy can be tested locally instead of only after a deploy.

## Layout

```
index.html          the page
404.html            served by the host for unmatched paths
style.css           all of it
_headers            response headers (Cloudflare Pages / Netlify format)
assets/img/         mark.svg, favicons, OG card
assets/fonts/       self-hosted woff2 + its OFL licence
tools/              build, serve, and the two CI check scripts
```

## Licence

Code and the shield mark: MIT, see `LICENSE`.
Protest Riot: SIL Open Font License, see `assets/fonts/OFL.txt`.
