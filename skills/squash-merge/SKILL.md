---
name: squash-merge
description: Use when the user wants to squash-merge a GitHub pull request — triggers include "squash merge", "land this PR", "merge the PR", "squash and merge", or any variant where a multi-commit branch needs to collapse into one commit on the base branch.
---

# Squash Merge

## Overview

Collapse a PR's multi-commit history into one well-titled commit on the base branch. The squash commit message is durable — it lives in `git log main` forever — so invest in making it accurate. **Always present a draft to the user before executing the merge.**

## When to use

- User says "squash merge", "merge this PR", "land it", "squash and merge"
- A PR is approved and ready for the base branch
- A branch has WIP/fixup commits that don't deserve to live in main's history

When NOT to use:
- User asks for a merge commit ("preserve history") — use `gh pr merge --merge`
- User asks for rebase-merge — use `gh pr merge --rebase`
- PR is not approved or CI is red — surface that first

## Workflow

1. **Identify the PR.** If the user didn't give a number, use `gh pr list --head $(git branch --show-current) --json number,url,title,state,isDraft`.

2. **Gather context in parallel** (use one message with multiple Bash calls):
   - `gh pr view <N> --repo <owner>/<repo> --json title,body,baseRefName,state,mergeable,reviewDecision`
   - `git log <base>..HEAD --oneline` — full commit history on the branch
   - `git log <base> --oneline -15` — recent base-branch commits, to detect message style

3. **Detect commit-message style.** Match what the project actually uses (Conventional Commits with scopes, BKBN style, plain titles). Do not impose Conventional Commits on a repo that doesn't use them.

4. **Check project commit-message rules.** Read CLAUDE.md / AGENTS.md / GEMINI.md if present. The common "title-only, no body" rule for feature-branch commits typically has an **exception for main-branch commits**: a squash to main lands as a single durable commit and will not be re-squashed, so a body IS appropriate when there's something worth saying. Honor whichever rule the project states.

5. **Draft title and body:**
   - **Title:** Match the repo's prefix style. ≤72 chars (ideally ≤70). Imperative mood. No trailing period.
   - **Body:** Short — what shipped and any salient architectural decision. Pull from the PR body where it captures the "why" well; do not re-paste the entire PR description. Wrap at 72 cols. Skip the body entirely for trivial PRs.

6. **Present the draft to the user.** Show title + body verbatim and ask for approval, edits, or a slim-down pass. **Do not skip this step even if the user already said "merge it"** — the durable commit message deserves one look.

7. **Merge after explicit approval:**
   ```bash
   gh pr merge <N> --repo <owner>/<repo> --squash \
     --subject "<approved title>" \
     --body "$(cat <<'EOF'
   <approved body, multi-line>
   EOF
   )"
   ```
   Use HEREDOC for the body to preserve formatting. Embedded newlines in `--body "..."` mangle the message.

8. **Verify.** `gh pr view <N> --json state,mergedAt,mergeCommit` should show `MERGED` with a commit SHA. Report the SHA to the user.

## Title patterns

| Repo style | Example |
|---|---|
| Conventional Commits, scoped | `feat(yoke-volume): add yoke-volume + yoke-volume-macos (sub-project C)` |
| Conventional Commits, unscoped | `feat: add OAuth2 login flow` |
| BKBN | `feature/[BKBN-1234] add user authentication` |

When the repo's style is unclear, default to Conventional Commits.

## Body guidelines

- Skip entirely for trivial PRs (one-line refactor, doc typo, dep bump).
- Include when the change has architectural weight or non-obvious motivation.
- 4–25 lines is the sweet spot. Long enough to capture the "why"; short enough that nobody skips it.
- Don't list files changed — `git show` does that. Capture the *decisions*.
- If the PR went through pivots during review, mention the *outcome* not the journey.

## Common mistakes

| Mistake | Fix |
|---|---|
| Merging without showing the draft | Always present title + body, even when the user said "merge it". |
| Re-pasting the entire PR body | Distill to what a future archaeologist needs. |
| Imposing Conventional Commits on a repo that doesn't use them | Match the repo. Read `git log <base>` first. |
| Multi-line body without HEREDOC | Use `--body "$(cat <<'EOF' ... EOF)"`. |
| Squashing when CI is red | Check `gh pr checks <N>` if mergeability is unclear. |
| Force-pushing or rebasing the branch first | Squash-merge handles the collapse — don't pre-collapse locally. |

## Red flags

- "The user said 'go'; skip the draft" → No. Show the draft.
- "I'll just use the PR title verbatim" → Read it once; it may have aged poorly during review rounds.
- "Body is fine as drafted, no slim-down pass" → Read as a future archaeologist would. Cut filler.
- "I'll squash locally then push" → Don't. Let `gh pr merge --squash` do it so the PR closes cleanly.
