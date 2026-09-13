#!/usr/bin/env bash
# Page weight budget. This exists because the first version of this site
# shipped a 19MB png, and nothing stopped it. CI fails if that comes back.
set -uo pipefail
cd "$(dirname "$0")/.."

# What a browser on a 2x screen actually pulls for a cold load of /.
CRITICAL=(index.html style.css assets/fonts/protest-riot-latin.woff2
          assets/img/hero-480.avif assets/img/favicon.png)

BUDGET_CRITICAL=$((150 * 1024))   # cold load on a retina screen
BUDGET_FILE=$((200 * 1024))       # no single tracked file
BUDGET_TOTAL=$((1024 * 1024))     # everything tracked in git

fail=0
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

echo "critical path (cold load, 2x screen)"
total=0
for f in "${CRITICAL[@]}"; do
  [ -f "$f" ] || { echo "  MISSING $f"; fail=1; continue; }
  sz=$(stat -c%s "$f"); total=$((total + sz))
  printf '  %10s  %s\n' "$(human "$sz")" "$f"
done
printf '  %10s  TOTAL (budget %s)\n' "$(human $total)" "$(human $BUDGET_CRITICAL)"
if [ "$total" -gt "$BUDGET_CRITICAL" ]; then
  echo "  OVER BUDGET by $(human $((total - BUDGET_CRITICAL)))"; fail=1
fi

echo
echo "largest tracked files (budget $(human $BUDGET_FILE) each)"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  sz=$(stat -c%s "$f")
  if [ "$sz" -gt "$BUDGET_FILE" ]; then
    printf '  OVER  %10s  %s\n' "$(human "$sz")" "$f"; fail=1
  fi
done < <(git ls-files)
git ls-files | while IFS= read -r f; do
  [ -f "$f" ] && printf '%s %s\n' "$(stat -c%s "$f")" "$f"
done | sort -rn | head -3 | while read -r sz f; do
  printf '  ok    %10s  %s\n' "$(human "$sz")" "$f"
done

echo
repo=0
while IFS= read -r f; do
  [ -f "$f" ] && repo=$((repo + $(stat -c%s "$f")))
done < <(git ls-files)
printf 'all tracked files: %s (budget %s)\n' "$(human $repo)" "$(human $BUDGET_TOTAL)"
[ "$repo" -gt "$BUDGET_TOTAL" ] && { echo "OVER BUDGET"; fail=1; }

echo
[ "$fail" -eq 0 ] && { echo "within budget"; exit 0; }
echo "budget exceeded"; exit 1
