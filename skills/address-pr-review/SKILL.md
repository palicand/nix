---
name: address-pr-review
description: Use when the user wants to act on review comments on a GitHub pull request — "go over review comments", "fix the PR feedback", "address the comments", "look at what the bot/reviewer flagged", "round 2 on the PR", or any variant where existing PR comments need to be evaluated and the still-valid ones turned into a follow-up commit. Covers fetching comments, filtering out already-resolved ones, verifying each finding against the current code before changing anything, asking the user before committing to heavy-lift suggestions, running the project's acceptance gates, and producing one clean commit ready to push. Pair-skill of receiving-code-review (which provides the disciplinary stance — verify first, no performative agreement, technical pushback when warranted).
---

# Address PR Review

## Overview

A reviewer (human or bot) has left comments on a GitHub PR. Each comment is a *suggestion to evaluate*, not an order to follow. Verify each one against the current code, decide what's still valid, ask the user before committing to anything that's large or design-shaping, then implement the agreed set in a single follow-up commit. The receiving-code-review skill governs the stance throughout — invoke it at the start if it isn't already loaded.

## When to Use

- "Go over the review comments on this PR"
- "There are several comments — address them"
- "Fix the things the bot flagged"
- "Round 2" / "2nd round" / "the new comments" after a push triggered a re-review
- Any time the user wants the open comment threads on the current PR turned into code

Do NOT use for:
- Comments on a PR the user hasn't opened yet (the comments don't exist; this is a different task)
- General code review work where you are the reviewer (use review / pr-review-toolkit instead)

## Inputs you need to know

Before acting, gather:

1. **The PR number and repo.** `gh pr view` with no args resolves to the current branch's PR. Use `gh pr view --json number,title,url,state,headRefName,baseRefName,body` to grab the metadata in one shot.
2. **The full comment payload.** `gh api repos/<owner>/<repo>/pulls/<num>/comments --paginate` returns every inline review comment with line numbers and bodies. Save the JSON to a temp file (it's often >50KB so don't try to read inline) and then `jq` it.
3. **The review summaries.** `gh api repos/<owner>/<repo>/pulls/<num>/reviews` shows top-level reviews that may already mark some threads "✅ Addressed in commit X" — the bot does this automatically when a follow-up commit lands.

## Workflow

### 1. Skill setup

If the **receiving-code-review** skill isn't already loaded in the conversation, invoke it now via the Skill tool. It's the disciplinary backbone: verify before implementing, no "you're absolutely right", push back on technically wrong suggestions, ask for clarification on unclear items. This skill assumes that stance throughout.

### 2. Inventory the comments

Pull the full list and dump readable summaries:

```bash
gh api repos/<owner>/<repo>/pulls/<num>/comments --paginate > /tmp/pr-comments.json
jq -r '.[] | "ID: \(.id)\t\(.path):\(.line // .original_line)\treply-to: \(.in_reply_to_id // "n/a")\tuser: \(.user.login)\tcreated: \(.created_at)"' /tmp/pr-comments.json | sort
```

For a "round 2" call where the bot re-reviewed after a push, filter to comments newer than the last review you addressed — `jq '.[] | select(.created_at > "<ISO timestamp>")'`. The user's prior commit timestamp from `git log` is usually the right floor.

Then read each comment body in full (`jq -r '.[] | select(.id == <ID>) | .body'`). CodeRabbit-style bots include large `<details>` blocks; the actionable claim is usually in the bold-text header right before the suggested-fix diff. Read all of it before deciding — they sometimes embed important caveats deep in the analysis section.

### 3. Verify each finding against the current code

This is the most important step and the one most easily skipped under time pressure. A comment claims "X is wrong"; the commit at the comment's `original_commit_id` may be older than the branch tip. The code may already be fixed.

For each comment:

- Use **LSP** (`findReferences`, `goToDefinition`, `documentSymbol`, `hover`) over Grep/Read when the question is semantic. Defaulting to text search wastes calls and misses renames.
- Read the relevant file at the latest tip. Don't assume the comment's snippet is current.
- If the bot already left a "✅ Addressed in commit X" marker on the thread (visible in `gh api repos/<owner>/<repo>/pulls/<num>/reviews`), confirm by reading the cited commit's diff with `git show`. If the fix is real, the comment is closed automatically — no reply needed.

Tabulate the result as still-valid vs already-addressed vs disagree-with-pushback. Quote the file:line for the still-valid ones so you can verify your own work later.

### 4. Branch decisions where the user has skin in the game

Some comments are obviously right (typo, missing language tag, dead constant rename). Some are obviously wrong (suggestion conflicts with a prior architectural decision the bot doesn't know about). The middle category — design-shaping changes, API signature changes, dependency additions — needs the user's call.

Use **AskUserQuestion** with 2-4 options (including a "skip / push back" option) for items like:

- "Should `setup()` return `Result<...>`? It's a trait-signature change."
- "Should we add this dev-dependency, or drop the diagnostic line entirely?"
- "Reviewer wants us to filter on disappear via IOKit ancestry walk. That's fragile when the device is gone. Track BSD names instead?"

Don't batch unrelated decisions into a single question — give each its own with the trade-off spelled out. Pre-rank the recommended option (label suffix "(Recommended)") so the user can hit Enter on the sensible default. **Skip this step entirely** if the user has said "work without stopping for clarifying questions" — in that case, make the call and document it in the commit body or the plan.

### 5. Implement

Order the work cheapest-first: doc/spec one-liners, then quick code fixes, then test changes, then anything touching public APIs. Doing it in this order means a clippy-/test-failure in the heavy lift doesn't leave the easy stuff uncommitted.

For each item:

- Edit the code (prefer `Edit` over `Write`; never re-`Read` files between Edit and verification — the harness tracks state).
- If you're changing a public function's signature or return type (e.g. `Option<X>` → `Vec<X>`), update **every** caller and **every** test. Use LSP's `findReferences` to find them all. Missing one is the most common way these PRs regress.
- Watch for spurious rust-analyzer diagnostics on macro expansions (`&[u8] vs &[u8; N]`, `tracing::warn!` Callsite types) — they don't reflect compiler reality. Trust `cargo check` over the LSP for those.
- When the test you added at first fails, don't just lower the assertion — re-read the code path and decide whether your fix or your test was wrong. Two times in three the test was wrong (over-conservative), but the third time the fix needs adjustment.

Add tests next to each behavioural change. Specifically:

- For a public-API guard change (e.g. "suppress no-op event on identical state"), add a same-state-in-same-state-out test.
- For an event-stream change (added events on a transition), add an assertion on the full event sequence.
- For a case-sensitivity fix, add the off-case input explicitly.
- For a refactor that shouldn't change behavior, the test is "existing tests still pass" — no new test needed.

### 6. Run the project's acceptance gates

Whatever the repo declares as a CI gate, run it locally before committing. For Rust:

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
# Plus any project-specific gates from AGENTS.md / CLAUDE.md, e.g.:
cargo build -p <crate> --target wasm32-unknown-unknown
cargo build --example <name> -p <crate>
```

For TS/JS: `yarn lint && yarn typecheck && yarn test`. For Kotlin: `./gradlew spotlessApply check`. Check the project's own AGENTS.md or CLAUDE.md for the canonical list — copy/paste it from there rather than guessing.

If a gate fails, the whole point of running them locally is that you can fix it before the bot or the user sees it. Don't commit a known-red diff.

### 7. Commit

One commit per round of review is the right grain — the bot re-reviews on every push, so each round of feedback gets exactly one follow-up. Title:

- Round 1: `fix(<area>): address PR #<num> review comments`
- Round 2+: `fix(<area>): address PR #<num> second-round review comments` (or "third-round", etc.)

Follow the project's commit conventions (e.g. BKBN's is "title only, no body"; yoke's is the same; some Anthropic projects want a Co-Authored-By line — check CLAUDE.md). If you had to make a non-obvious call without asking the user (because they said don't ask), put a one-line note in the commit body explaining the call.

Stage explicitly — `git add` the specific files, not `git add -A`. Catch yourself before staging `Cargo.lock` if the project's convention says not to.

### 8. Don't push without permission

Stop after the commit. Show the user the summary table (what changed, what was skipped and why) and let them push. Pushing without explicit permission is the most common way these workflows surprise the user — they might want to inspect the diff first, or batch with another change.

When the user pushes and the bot re-reviews, expect a "2nd round" continuation. The pattern repeats: filter to new comments, verify, fix, commit, stop.

## Reporting back

Use a compact table for the summary:

| # | Item | What changed (file:line) |
|---|---|---|
| 1 | Short description | path → behaviour |

Plus a one-line summary per acceptance gate (e.g. `cargo test --workspace — 118 passed`). For "addressed in earlier commit by the bot's auto-marker, no action needed", call it out separately so the user can see the bot was right.

## Anti-patterns to avoid

- **Implementing without verifying the comment's still valid.** The bot often comments on snapshots; the branch tip may differ. Always re-read the file.
- **Batching unrelated decisions into one AskUserQuestion.** Each design call gets its own question; the user can't sensibly answer "A,B,C" when each was a different judgment.
- **Accepting the bot's suggested diff verbatim.** They're often a reasonable starting point but rarely the final form. The diff for the Present→DeviceVisibleNoVolume case in yoke was technically right but missed the API-shape question (Option vs Vec).
- **Adding tests for assertions that were already true under existing callers.** A defensive guard in a `pub fn` may never trigger from the in-tree callers — that doesn't mean it's not worth adding, but justify it as "this function is public, future callers might call it directly" rather than as "fixing a current bug".
- **Skipping the gates because "it's a small change".** The acceptance gates exist because small changes break things. Run them every time.
- **Pushing without confirmation.** Always stop at the commit.

## YAGNI checks

When a reviewer suggests "implement this properly" for code that isn't called yet:

- `grep` (or LSP `findReferences`) for actual call sites. If there are none, *remove* the unused code instead of fixing it.
- If the spec mentions future use (e.g. "we'll switch to IOServiceAddMatchingNotification later"), fix the minimum needed to be future-correct, but don't add the *new* unused thing they suggested on top.

The reviewer's job is finding issues. The user's job, and yours, is deciding which issues are worth fixing *now*.
