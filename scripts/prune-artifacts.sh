#!/usr/bin/env bash
# Delete Actions artifacts older than N days (default 30).
#
# Runs are the main source of artifact garbage, and prune-runs.sh already
# deletes all but the newest few runs of the workflow that calls it - which
# removes their artifacts with them. This script catches the rest: artifacts of
# runs the repository wants to keep, artifacts from other workflows, and
# anything GitHub has already marked expired.
#
# Needs `actions: write`; the prune job in build-openwrt.yml grants it.
#
# Usage: prune-artifacts.sh [days]      default days=30
set -euo pipefail

days="${1:-30}"
if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -lt 1 ]; then
  echo "::error::days must be a positive integer (got '$days')"
  exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
  echo "::warning::gh is not available; skipping the artifact cleanup"
  exit 0
fi

repo="${GITHUB_REPOSITORY:-}"
if [ -z "$repo" ]; then
  echo "::warning::GITHUB_REPOSITORY is not set; skipping the artifact cleanup"
  exit 0
fi
export GH_REPO="$repo"

# ISO-8601, which is what the artifacts API returns in created_at, so the
# comparison is a plain string comparison.
cutoff=$(date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%SZ)

echo "Deleting artifacts of $repo older than $days days (before $cutoff)"

ids=$(gh api "repos/$repo/actions/artifacts?per_page=100" --paginate \
  --jq ".artifacts[] | select(.expired == true or .created_at < \"$cutoff\") | .id" || true)

deleted=0
for id in $ids; do
  if gh api --method DELETE "repos/$repo/actions/artifacts/$id" > /dev/null 2>&1; then
    deleted=$((deleted + 1))
  else
    echo "::warning::could not delete artifact $id"
  fi
done

echo "Deleted $deleted artifact(s)."
