#!/usr/bin/env bash
# Assert the security headers from _headers are actually present on a URL.
# Run against the deployed site; CI fails the build if any of these regress.
#
#   tools/check-headers.sh https://example.pages.dev
#
# Locally: start tools/serve.py first, then point this at http://127.0.0.1:8000
set -uo pipefail

url="${1:-}"
[ -n "$url" ] || { echo "usage: $0 <url>" >&2; exit 2; }

hdrs="$(curl -sSL --max-time 20 -D - -o /dev/null "$url")" || {
  echo "could not fetch $url" >&2; exit 1; }

fail=0
pass=0

# name <TAB> extended-regex the value must match
check() {
  local name="$1" want="$2" got
  got="$(printf '%s' "$hdrs" | grep -i "^$name:" | tail -1 | cut -d: -f2- | sed 's/^ *//; s/\r$//')"
  if [ -z "$got" ]; then
    printf '  MISSING  %s\n' "$name"; fail=$((fail+1)); return
  fi
  if printf '%s' "$got" | grep -qiE "$want"; then
    printf '  ok       %s\n' "$name"; pass=$((pass+1))
  else
    printf '  BAD      %s\n           got:  %s\n           want: /%s/\n' "$name" "$got" "$want"
    fail=$((fail+1))
  fi
}

echo "checking $url"
check "Content-Security-Policy"       "default-src 'none'"
check "Content-Security-Policy"       "frame-ancestors 'none'"
check "Content-Security-Policy"       "base-uri 'none'"
check "X-Content-Type-Options"        "^nosniff$"
check "X-Frame-Options"               "^DENY$"
check "Referrer-Policy"               "^(no-referrer|strict-origin-when-cross-origin)$"
check "Cross-Origin-Opener-Policy"    "^same-origin$"
check "Cross-Origin-Resource-Policy"  "^same-origin$"
check "Permissions-Policy"            "geolocation=\(\)"
check "Permissions-Policy"            "camera=\(\)"
check "Permissions-Policy"            "microphone=\(\)"

# HSTS is only meaningful over https, and Cloudflare/Netlify will not send it
# on a plain http origin.
case "$url" in
  https://*) check "Strict-Transport-Security" "max-age=(6[0-9]{7}|[1-9][0-9]{8,})" ;;
  *)         echo "  skip     Strict-Transport-Security (not https)" ;;
esac

# The page must not be advertising a server it does not need to.
if printf '%s' "$hdrs" | grep -qiE '^(x-powered-by|x-aspnet-version):'; then
  echo "  BAD      x-powered-by / x-aspnet-version disclosed"; fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "$fail check(s) failed, $pass passed"
  exit 1
fi
echo "all $pass checks passed"
