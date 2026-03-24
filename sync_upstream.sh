#!/usr/bin/env bash
set -euo pipefail

upstream_remote='upstream'
upstream_branch='master'
branch='main'

usage() {
  echo 'Usage:'
  echo '  sync_upstream.sh <UPSTREAM_COMMIT_SHA|latest> [--tag TAGNAME]'
}

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
  usage
  exit 2
fi

target="$1"
tag_name=''

if [ "${2:-}" = '--tag' ]; then
  if [ -z "${3:-}" ]; then
    echo 'Error: --tag requires a value'
    exit 2
  fi
  tag_name="$3"
fi

git remote get-url "$upstream_remote" >/dev/null 2>&1 || {
  echo "Missing remote '$upstream_remote'"
  exit 1
}

git fetch "$upstream_remote" --tags
git fetch origin --tags

git checkout "$branch"

# Preserve fork-owned files
tmp_dir="$(mktemp -d)"
cp README.md "$tmp_dir/README.md"
cp sync_upstream.sh "$tmp_dir/sync_upstream.sh"

# Resolve target commit
if [ "$target" = 'latest' ]; then
  target_sha="$(git rev-parse "$upstream_remote/$upstream_branch")"
else
  target_sha="$target"
fi

git cat-file -e "${target_sha}^{commit}" 2>/dev/null || {
  echo "Invalid commit: $target_sha"
  rm -rf "$tmp_dir"
  exit 1
}

# Reset to upstream commit
git reset --hard "$target_sha"

# Restore fork-owned files
cp "$tmp_dir/README.md" README.md
cp "$tmp_dir/sync_upstream.sh" sync_upstream.sh
chmod +x sync_upstream.sh
rm -rf "$tmp_dir"

# Commit fork-owned files if needed
if ! git diff --quiet -- README.md sync_upstream.sh; then
  git add README.md sync_upstream.sh
  git commit -m "Fork: preserve README and sync_upstream after upstream sync (${target_sha:0:12})"
fi

# Push rewritten history safely
git push origin "$branch" --force-with-lease

# Tagging
if [ -z "$tag_name" ]; then
  tag_name="r$(date -u +%F)"
fi

if git rev-parse -q --verify "refs/tags/$tag_name" >/dev/null; then
  existing_sha="$(git rev-list -n 1 "$tag_name")"
  head_sha="$(git rev-parse HEAD)"
  if [ "$existing_sha" != "$head_sha" ]; then
    echo "Tag $tag_name already exists and does not point to HEAD"
    exit 1
  fi
else
  git tag -a "$tag_name" -m "Release $tag_name (upstream ${target_sha:0:12})"
  git push origin "$tag_name"
fi
echo "Synchronized to upstream commit $target_sha and tagged as $tag_name"
