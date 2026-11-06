#!/bin/bash
# Shows what upstream (govijr/terminal-mac) has added since this fork last synced, and optionally
# integrates it. Upstream keeps no changelog, so its commits are the release notes.
#
#   bash scripts/sync-upstream.sh            # fetch and list new upstream commits (no changes)
#   bash scripts/sync-upstream.sh --stat     # same, plus the files each commit touched
#   bash scripts/sync-upstream.sh --rebase   # replay my commits on top of upstream/main
#   bash scripts/sync-upstream.sh --merge    # merge upstream/main into the current branch
#
# After --rebase, push with: git push --force-with-lease origin HEAD
# After --merge, push with:  git push origin HEAD
# Then rebuild and reinstall: bash scripts/build.sh && bash scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

mode=list
case "${1:-}" in
  '') ;;
  --stat) mode=stat ;;
  --rebase) mode=rebase ;;
  --merge) mode=merge ;;
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Unknown argument: $1 (use --stat, --rebase or --merge)" >&2; exit 1 ;;
esac

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/govijr/terminal-mac.git
git fetch --quiet --tags upstream

branch="$(git rev-parse --abbrev-ref HEAD)"
base="$(git merge-base HEAD upstream/main)"
new_count="$(git rev-list --count HEAD..upstream/main)"
mine_count="$(git rev-list --count upstream/main..HEAD)"

echo "Branch:      $branch"
echo "Fork point:  $(git log -1 --format='%h %ad %s' --date=short "$base")"
echo "Upstream:    $(git log -1 --format='%h %ad %s' --date=short upstream/main)"
echo "My commits not in upstream: $mine_count"
echo
if [[ "$new_count" -eq 0 ]]; then
  echo 'Upstream has no new commits since the fork point.'
  exit 0
fi
echo "New upstream commits ($new_count), oldest first:"
if [[ "$mode" = stat ]]; then
  git log --reverse --stat --format='%n%h %ad %s' --date=short HEAD..upstream/main
else
  git log --reverse --oneline HEAD..upstream/main
fi

case "$mode" in
  list|stat) echo; echo 'Nothing changed. Rerun with --rebase or --merge to integrate.' ;;
  rebase|merge)
    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
      echo 'Working tree has uncommitted changes; commit or stash them first.' >&2; exit 1
    fi
    echo
    if [[ "$mode" = rebase ]]; then
      git rebase upstream/main
      echo "Rebased $branch onto upstream/main. Push: git push --force-with-lease origin HEAD"
    else
      git merge --no-edit upstream/main
      echo "Merged upstream/main into $branch. Push: git push origin HEAD"
    fi
    echo 'Rebuild and reinstall: bash scripts/build.sh && bash scripts/install.sh'
    ;;
esac
