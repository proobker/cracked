#!/usr/bin/env bash
# Publishes site/ to the gh-pages branch (builds go on GitHub releases),
# served by GitHub Pages at https://cracked.rabidahal.com.np.
#   bash tools/deploy_site.sh
set -euo pipefail
# Run from PowerShell, bash may put Windows System32 (whose find.exe differs)
# ahead of its own tools; prefer the Unix ones.
export PATH="/usr/bin:/bin:$PATH"
cd "$(dirname "$0")/.."

DOMAIN="cracked.rabidahal.com.np"
WT="$(mktemp -d)"
trap 'git worktree remove --force "$WT" >/dev/null 2>&1 || true' EXIT

git fetch origin gh-pages >/dev/null 2>&1 || true
if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
  git worktree add -B gh-pages "$WT" origin/gh-pages >/dev/null
else
  git worktree add --detach "$WT" >/dev/null
  git -C "$WT" checkout --orphan gh-pages >/dev/null
fi

# Replace everything except .git with the current site.
find "$WT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r site/. "$WT"/
find "$WT" \( -name "*.import" -o -name ".gdignore" \) -delete
rm -rf "$WT/downloads"
printf '%s\n' "$DOMAIN" > "$WT/CNAME"
touch "$WT/.nojekyll"

git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then
  echo "Site unchanged; nothing to deploy."
  exit 0
fi
git -C "$WT" commit -q -m "site: deploy $(git rev-parse --short HEAD)"
git -C "$WT" push -q origin gh-pages
echo "Deployed to https://$DOMAIN"
