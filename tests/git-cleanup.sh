#!/usr/bin/env bash
# usage: git-cleanup.sh <git-cleanup binary>
set -euo pipefail

cleanup_bin=$1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export HOME=$work GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git config --global init.defaultBranch master

mkdir "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/bin/sh
cat "$HOME/prs.tsv"
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"

git init -q --bare "$work/origin.git"
git clone -q "$work/origin.git" "$work/repo" 2>/dev/null
cd "$work/repo"
commit() { echo "$2" >"$1" && git add "$1" && git commit -qm "$1: $2"; }
old() { GIT_COMMITTER_DATE=2020-01-01T00:00:00 GIT_AUTHOR_DATE=2020-01-01T00:00:00 "$@"; }

printf '1\n2\n3\n4\n5\n' >ctx.txt
commit base.txt 0
git add ctx.txt && git commit -qm ctx
git push -q origin master

git switch -qc merged && commit m.txt 1 && git switch -q master && git merge -q --ff-only merged

git switch -qc squashed && commit s.txt 1 && git switch -q master
git merge -q --squash squashed && git commit -qm "squash"

git switch -qc context && sed -i.bak 's/^1$/one/' ctx.txt && rm ctx.txt.bak && git commit -qam ctx-one
git switch -q master && sed -i.bak 's/^3$/three/' ctx.txt && rm ctx.txt.bak && git commit -qam ctx-three
git merge -q --squash context && git commit -qm "squash context"
git push -q origin master

git switch -qc closed-pr master && commit c.txt 1
git switch -qc open-pr master && old commit o.txt 1
git switch -qc stale master && old commit st.txt 1
git switch -qc fresh master && commit f.txt 1
git switch -qc stale-dirty master && old commit sd.txt 1
git switch -q master
printf 'closed-pr\t%s\tCLOSED\nopen-pr\t%s\tOPEN\n' "$(git rev-parse closed-pr)" "$(git rev-parse open-pr)" >"$HOME/prs.tsv"

git worktree add -q "$work/wt-dirty" stale-dirty
echo edit >>"$work/wt-dirty/sd.txt"
git worktree add -q "$work/wt-stale" stale
git worktree add -q --detach "$work/wt-detached" master
touch -t 202001010000 "$(git -C "$work/wt-detached" rev-parse --absolute-git-dir)/HEAD"

fail() {
  echo "FAIL: $*" >&2
  echo "$out" >&2
  exit 1
}
out=$("$cleanup_bin" 2>&1)
for b in merged squashed context closed-pr stale; do
  echo "$out" | grep -qE "^  $b  \[" || fail "dry run does not list $b"
done
echo "$out" | grep -qF "  context  [content already in origin/master]" || fail "context not detected by content"
echo "$out" | grep -qF "  closed-pr  [PR closed]" || fail "closed-pr reason"
echo "$out" | grep -qF "  stale  [stale, last commit" || fail "stale reason"
echo "$out" | grep -qF "(worktree: $work/wt-detached)" || fail "detached worktree not listed"
echo "$out" | grep -qF "stale-dirty  (uncommitted changes" || fail "dirty worktree not kept"
for b in open-pr fresh master; do
  echo "$out" | grep -qE "^  $b  \[" && fail "dry run lists $b"
done

out=$("$cleanup_bin" -f 2>&1)
remaining=$(git for-each-ref --format='%(refname:lstrip=2)' refs/heads | sort | tr '\n' ' ')
[ "$remaining" = "fresh master open-pr stale-dirty " ] || fail "remaining branches: $remaining"
[ ! -e "$work/wt-stale" ] && [ ! -e "$work/wt-detached" ] || fail "worktrees not removed"
[ -e "$work/wt-dirty" ] || fail "dirty worktree removed"
echo "git-cleanup: ok"
