force=0
case "${1-}" in
  -f | --force) force=1 ;;
  "") ;;
  *)
    echo "usage: git cleanup [-f|--force]" >&2
    exit 2
    ;;
esac

stale_days=$(git config --int --get cleanup.staleDays || echo 30)

git fetch -p || echo "fetch failed; using cached remote refs" >&2
if git rev-parse --verify -q origin/main >/dev/null; then
  base=origin/main
elif git rev-parse --verify -q origin/master >/dev/null; then
  base=origin/master
else
  echo "no origin/main or origin/master to compare against" >&2
  exit 1
fi
base_tree=$(git rev-parse "$base^{tree}")
current=$(git symbolic-ref -q --short HEAD || true)
here=$(git rev-parse --show-toplevel)
now=$(date +%s)

main_wt=""
declare -A worktree_of
detached=()
while read -r key val; do
  case $key in
    worktree)
      wt=$val
      [ -n "$main_wt" ] || main_wt=$wt
      ;;
    HEAD) head=$val ;;
    branch) worktree_of[${val#refs/heads/}]=$wt ;;
    detached) [ "$wt" = "$main_wt" ] || detached+=("$wt"$'\t'"$head") ;;
  esac
done < <(git worktree list --porcelain)

# Branches pushed with an explicit refspec have no upstream, so "[gone]" never fires for them;
# the PR state is the only record that their work is finished.
prs=""
if command -v gh >/dev/null; then
  prs=$(gh pr list --state all --limit 5000 --json headRefName,headRefOid,state,isCrossRepository \
    --jq '.[] | select(.isCrossRepository | not) | [.headRefName, .headRefOid, .state] | @tsv' 2>/dev/null) ||
    {
      prs=""
      echo "note: could not list PRs; PR-based detection skipped" >&2
    }
fi

has_tracked_changes() { [ -n "$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)" ]; }
on_remote() { [ -n "$(git branch -r --contains "$1" 2>/dev/null)" ]; }

classify() {
  local ref="refs/heads/$1" mb tree name oid state ts age
  reason=""
  if git merge-base --is-ancestor "$ref" "$base"; then
    reason=merged
    return
  fi
  if [ "$(git for-each-ref --format='%(upstream:track)' "$ref")" = "[gone]" ]; then
    reason="upstream gone"
    return
  fi
  if mb=$(git merge-base "$base" "$ref"); then
    if [[ $(git cherry "$base" "$(git commit-tree "$ref^{tree}" -p "$mb" -m _)") == -* ]]; then
      reason=squashed
      return
    fi
    # Patch-id matching misses squashes whose diff context changed on $base; a no-op merge doesn't.
    if tree=$(git merge-tree --write-tree "$base" "$ref" 2>/dev/null) && [ "$tree" = "$base_tree" ]; then
      reason="content already in $base"
      return
    fi
  fi
  while IFS=$'\t' read -r name oid state; do
    [ "$name" = "$1" ] && [ "$state" = OPEN ] && return
  done <<<"$prs"
  while IFS=$'\t' read -r name oid state; do
    [ "$name" = "$1" ] || continue
    if git merge-base --is-ancestor "$ref" "$oid" 2>/dev/null; then
      reason="PR ${state,,}"
      return
    fi
  done <<<"$prs"
  if ((stale_days > 0)); then
    ts=$(git log -1 --format=%ct "$ref")
    age=$(((now - ts) / 86400))
    if ((age >= stale_days)); then
      reason="stale, last commit ${age}d ago"
      on_remote "$ref" || reason+=", unpushed"
    fi
  fi
}

cand_branch=()
cand_reason=()
cand_wt=()
kept=()
add() {
  cand_branch+=("$1")
  cand_reason+=("$2")
  cand_wt+=("$3")
}

while IFS= read -r b; do
  case $b in main | master | "$current") continue ;; esac
  wt=${worktree_of[$b]-}
  [ "$wt" != "$main_wt" ] || continue
  classify "$b"
  [ -n "$reason" ] || continue
  if [ -n "$wt" ] && has_tracked_changes "$wt"; then
    kept+=("$b  (uncommitted changes in $wt)")
    continue
  fi
  add "$b" "$reason" "$wt"
done < <(git for-each-ref --format='%(refname:lstrip=2)' refs/heads)

if ((stale_days > 0)); then
  for entry in ${detached[@]+"${detached[@]}"}; do
    wt=${entry%%$'\t'*}
    head=${entry#*$'\t'}
    [ "$wt" != "$here" ] || continue
    on_remote "$head" || continue
    gitdir=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) || continue
    [ -n "$(find "$gitdir/HEAD" -mtime "+$stale_days" 2>/dev/null)" ] || continue
    if has_tracked_changes "$wt"; then
      kept+=("detached worktree $wt  (uncommitted changes)")
      continue
    fi
    add "" "detached at ${head:0:9}, untouched ${stale_days}d+" "$wt"
  done
fi

if [ ${#kept[@]} -gt 0 ]; then
  echo "Keeping:"
  printf '  %s\n' "${kept[@]}"
fi
if [ ${#cand_reason[@]} -eq 0 ]; then
  echo 'Nothing to clean up'
  exit 0
fi

if [ "$force" -ne 1 ]; then
  echo "Would remove (base $base):"
  for i in "${!cand_reason[@]}"; do
    printf '  %s  [%s]%s\n' "${cand_branch[$i]:-(detached)}" "${cand_reason[$i]}" "${cand_wt[$i]:+  (worktree: ${cand_wt[$i]})}"
  done
  echo "Run 'git cleanup -f' to delete."
  exit 0
fi

for i in "${!cand_reason[@]}"; do
  b=${cand_branch[$i]}
  wt=${cand_wt[$i]}
  if [ -n "$wt" ]; then
    echo "Removing worktree $wt"
    git worktree remove --force "$wt" || continue
  fi
  [ -z "$b" ] || git branch -D "$b" || true
done
git worktree prune
