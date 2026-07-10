---
name: announce-mr
description: Use when a merge request (or pull request) has just been created and the team needs to know about it on Slack — covers channel selection, one-sentence message composition, caveat threading, and mandatory user approval before posting
---

# Announce MR on Slack

## Overview

After a merge request is created, announce it in the team's `dev-*` Slack channel: a one-sentence summary plus the URL on its own line. Caveats go as a thread reply, never in the headline. Always show the composed plan to the user and wait for explicit approval before calling any Slack send tool.

## When to Use

- Immediately after `glab mr create` / `gh pr create` succeeds and returns a URL
- User asks to "share", "announce", "post", "ping the team", or "tell #dev" about an MR
- After an MR-creation flow where the user did not say they'll share it themselves

Do NOT use for:
- Draft MRs unless the user explicitly says to announce them
- MR updates (new commits pushed) — only the initial announcement
- Re-announcing an MR already posted earlier in this session
- When the user says "I'll share it" or similar

## Workflow

1. **Collect MR facts** — title, URL, ISSUE-id (from branch), and what changed. If you just created the MR you already have these; don't re-fetch.

2. **Resolve the Slack channel** for the repo:
   - Check auto-memory for `slack_channel_<repo-name>` (e.g. `slack_channel_backend-platform.md`)
   - If unknown, call `slack_search_channels` with query `dev` and pick the closest match by repo name (`backend-platform` → `dev-backend`, `frontend-platform` → `dev-frontend`, `infrastructure-*` → `dev-infra` / `dev-devops`)
   - If there is no clear winner, ask the user once and save the answer to memory as a `reference` memory

3. **Compose the headline** — one sentence, no fluff:
   - Start with the ISSUE-id if present in the branch
   - Describe WHAT the MR does, not how
   - No greetings ("Hey team!"), no emoji, no "This MR..."
   - URL goes on its own line so Slack unfurls it

   ```
   ISSUE-1234: Add idempotency keys to payment webhook handler.
   https://gitlab.bkbn.com/.../merge_requests/4567
   ```

4. **Identify caveats** — only ones that are genuinely warranted. **Default to zero.** Most MRs need no thread.

   The bar: a caveat earns a thread reply *only* if it tells a teammate something they must **DO** or **KNOW** that they would NOT get by opening the MR. If the diff or MR description already shows it, it is not a caveat.

   Warranted (thread it):
   - Behind a feature flag (name + default state)
   - Requires a migration, config change, or manual ops step before/after merge
   - Breaks an interface or touches shared infra other teams depend on
   - Marked WIP / blocked on another MR / stacked on top of another MR
   - A real security- or performance-sensitive change reviewers should scrutinize

   NOT warranted (leave it out — these are nitpicks, not caveats):
   - Renames, reformatting (spotless), moved methods, KDoc/comment tweaks
   - Patch/transitive dependency bumps
   - "Reviewer hint" on a small or single-purpose MR — only worth a thread when the diff is genuinely large and the signal-to-noise is low enough that pointing at the load-bearing file actually saves the reviewer time. Do not invent a hint just to have a caveat, and never aggregate nitpicks into one "hint" reply.

   One caveat per thread reply. **When in doubt, leave it out** — an unwarranted caveat is worse than none.

5. **Show the plan to the user and wait for approval:**

   ```
   Channel: #dev-backend
   Message: ISSUE-1234: Add idempotency keys to payment webhook handler.
            https://gitlab.bkbn.com/.../merge_requests/4567

   Thread replies:
     1. Behind feature flag `payments.idempotency` (default off).
     2. Migration 0042 must be applied before merge.

   OK to post?
   ```

   Wait for explicit "yes" / "send it" / "post it". A prior "and post to Slack when done" is **not** approval — show the composed message first.

6. **Post** once approved:
   - Send the headline via `slack_send_message` to the chosen channel
   - Capture the returned message timestamp (`ts`)
   - For each caveat, send a `slack_send_message` reply targeting that `ts`

7. **Save the channel mapping** to memory if newly resolved this session. Reference memory, e.g.:
   ```
   ---
   name: slack-channel-backend-platform
   description: Slack channel for backend-platform MR announcements
   metadata:
     type: reference
   ---
   backend-platform MRs → #dev-backend
   ```
   And add the index line to `MEMORY.md`.

## Channel selection rules

| Repo | Channel pattern |
|------|-----------------|
| `backend-platform` | `dev-backend` (verify on first use) |
| `frontend-platform` | `dev-frontend` (verify on first use) |
| `infrastructure-gcp` | `dev-infra` / `dev-devops` (verify on first use) |
| `infrastructure-services` | same as above |
| `infrastructure-gitlab-ci` | same as above or `dev-ci` |
| Anything else | Search `dev-*`, propose the closest, save once confirmed |

The `dev-` prefix is the strong heuristic. Never guess silently — propose, get confirmation, save the mapping.

## Message format rules

- **One sentence.** If you need two, you're describing implementation; cut it.
- Imperative or descriptive voice: "Add X", "Switch Y to Z" — not "I have added..." or "This MR will..."
- ISSUE-id (or QA-id) prefix when the branch has one
- URL on its own line, no Markdown brackets — Slack unfurls bare URLs cleanly
- No emoji, no greetings, no signature

## What counts as a caveat (thread)

**The warrant test:** thread it only if a teammate must DO or KNOW it and the MR itself wouldn't tell them. Default to no caveats — most MRs don't need any.

Warranted:
- Feature flags and their default state
- Required follow-up actions (migrations, configs, manual ops)
- Known limitations or follow-up tickets that block relying on the change
- Dependencies on other MRs
- Reviewer hint *only* when the diff is large enough that pointing at the load-bearing file genuinely saves time

Do NOT include (these are nitpicks, not caveats):
- Apologies, hedges, or self-deprecation ("sorry it's big")
- Anything the diff already shows ("changed 12 files", renames, reformats, moved methods)
- Patch/transitive dependency bumps, comment/KDoc tweaks
- Reviewer hints on small or single-purpose MRs
- Reasoning the MR description already covers
- A "hint" that is really several nitpicks bundled together to look load-bearing

## Approval gate — non-negotiable

Even when the user has pre-authorized announcement, show the composed message and channel **before** sending. The Slack tools are not reversible; a wrong channel or typo is visible to everyone immediately. This step costs the user one reply and prevents the failure mode of posting half-baked summaries.

## Common mistakes

- **Posting without showing the plan first** — "I'll just send it, they said to post" is wrong. Always show.
- **Folding caveats into the headline** — makes the unfurl noisy, defeats the one-sentence rule.
- **Silent channel guesses** — if memory has no entry, propose + confirm + save; don't pick and post.
- **Re-announcing** — if you already posted earlier in the session, stop.
- **Including the MR description verbatim** — the link unfurls; the headline is the *hook*, not a copy of the body.
- **Threading trivia** — only post a thread reply if it clears the warrant test (a DO-or-KNOW a teammate wouldn't get from the MR). Default to no caveats; renames, reformats, dep bumps, and small-MR "reviewer hints" don't qualify.

## Red flags — stop and re-check

- About to call `slack_send_message` without having shown the plan → STOP, show it
- About to post to a channel you picked from memory without verifying it still exists → fine, but if Slack returns "channel not found", ask the user, don't search and pick another silently
- Any caveat that survives because you bundled nitpicks (renames, reformats, dep bumps) into one "reviewer hint" → that is over-threading; drop it. If each item alone wouldn't clear the warrant test, the bundle doesn't either.
- About to write a thread reply you can't tie to a concrete DO-or-KNOW for a teammate → STOP, leave it out
- Caveat list is longer than 4 items → likely conflating "things to mention" with "things the reviewer must know"; trim
