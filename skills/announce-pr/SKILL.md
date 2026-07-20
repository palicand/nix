---
name: announce-pr
description: Use when a GitHub pull request has just been created and the team needs to know about it on Slack — covers channel selection, one-sentence message composition, caveat threading, and mandatory user approval before posting
---

# Announce PR on Slack

## Overview

After a pull request is created, announce it in the team's `dev-*` Slack channel: a one-sentence summary plus the URL on its own line. Caveats go as a thread reply, never in the headline. Always show the composed plan to the user and wait for explicit approval before calling any Slack send tool.

## When to Use

- Immediately after `gh pr create` succeeds and returns a URL
- User asks to "share", "announce", "post", "ping the team", or "tell #dev" about a PR
- After a PR-creation flow where the user did not say they'll share it themselves

Do NOT use for:
- Draft PRs unless the user explicitly says to announce them
- PR updates (new commits pushed) — only the initial announcement
- Re-announcing a PR already posted earlier in this session
- When the user says "I'll share it" or similar

## Workflow

1. **Collect PR facts** — title, URL, ISSUE-id (from branch), and what changed. If you just created the PR you already have these; don't re-fetch.

2. **Resolve the Slack channel** for the repo:
   - Check auto-memory for `slack_channel_<repo-name>` (e.g. `slack_channel_backend-platform.md`)
   - If unknown, call `slack_search_channels` with query `dev` and pick the closest match by repo name (`backend-platform` → `dev-backend`, `frontend-platform` → `dev-frontend`, `infrastructure-*` → `dev-infra` / `dev-devops`)
   - If there is no clear winner, ask the user once and save the answer to memory as a `reference` memory

3. **Compose the headline** — one sentence, no fluff:
   - Start with the ISSUE-id if present in the branch
   - Describe WHAT the PR does, not how
   - No greetings ("Hey team!"), no emoji, no "This PR..."
   - URL goes on its own line so Slack unfurls it

   ```
   ISSUE-1234: Add idempotency keys to payment webhook handler.
   https://github.com/bkbn-com/backend-platform/pull/4567
   ```

4. **Identify caveats** — only ones that are genuinely warranted. **Default to zero.** Most PRs need no thread.

   The bar: a caveat earns a thread reply *only* if it tells a teammate something they must **DO** or **KNOW** that they would NOT get by opening the PR. If the diff or PR description already shows it, it is not a caveat.

   Warranted (thread it):
   - Behind a feature flag (name + default state)
   - Requires a migration, config change, or manual ops step before/after merge
   - Breaks an interface or touches shared infra other teams depend on
   - Marked draft / blocked on another PR / stacked on top of another PR
   - A real security- or performance-sensitive change reviewers should scrutinize

   NOT warranted (leave it out — these are nitpicks, not caveats):
   - Renames, reformatting (spotless), moved methods, KDoc/comment tweaks
   - Patch/transitive dependency bumps
   - "Reviewer hint" on a small or single-purpose PR — only worth a thread when the diff is genuinely large and the signal-to-noise is low enough that pointing at the load-bearing file actually saves the reviewer time. Do not invent a hint just to have a caveat, and never aggregate nitpicks into one "hint" reply.

   One caveat per thread reply. **When in doubt, leave it out** — an unwarranted caveat is worse than none.

5. **Show the plan to the user and wait for approval:**

   ```
   Channel: #dev-backend
   Message: ISSUE-1234: Add idempotency keys to payment webhook handler.
            https://github.com/bkbn-com/backend-platform/pull/4567

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
   description: Slack channel for backend-platform PR announcements
   metadata:
     type: reference
   ---
   backend-platform PRs → #dev-backend
   ```
   And add the index line to `MEMORY.md`.

## Multiple or companion PRs

Sometimes one feature ships as two or more PRs (e.g. a platform half + a service half, or a stacked chain). **Never put more than one URL in a single Slack message** — Slack merges adjacent bare URLs into one combined unfurl, so the second link effectively disappears. One message, one URL, always.

Structure a companion set as a thread so the halves stay grouped and each URL unfurls on its own:

- **Parent message:** the one-sentence feature summary + the *primary* PR's URL on its own line (one URL only).
- **One thread reply per additional PR:** a short clause naming that half + its URL on its own line. E.g. `Service half (service-crm-integrations): consumes the endpoint in the push resolver.` then the URL.
- **Then** the caveats as further thread replies, one per reply as usual.

Each PR link and each caveat is its own message. If the PRs are unrelated (not one feature), announce them separately with the full workflow each, rather than threading them together.

When you show the plan for approval, lay the thread out explicitly so the user sees each URL lands in its own message:

```
Channel: #dev-backend
Message: ISSUE-2336: Resolve the workspace for Propstack property pushes.
         https://github.com/bkbn-com/backend-platform/pull/3421

Thread replies:
  1. Service half (service-crm-integrations): consumes the endpoint.
     https://github.com/bkbn-com/backend-services/pull/330
  2. Deploy the platform half before/with the service half; else pushes fail closed.

OK to post?
```

## Channel selection rules

| Repo | Channel pattern |
|------|-----------------|
| `backend-platform` | `dev-backend` (verify on first use) |
| `frontend-platform` | `dev-frontend` (verify on first use) |
| `infrastructure-gcp` | `dev-infra` / `dev-devops` (verify on first use) |
| `infrastructure-services` | same as above |
| `infrastructure-github-ci` | same as above or `dev-ci` |
| Anything else | Search `dev-*`, propose the closest, save once confirmed |

The `dev-` prefix is the strong heuristic. Never guess silently — propose, get confirmation, save the mapping.

## Message format rules

- **One sentence.** If you need two, you're describing implementation; cut it.
- Imperative or descriptive voice: "Add X", "Switch Y to Z" — not "I have added..." or "This PR will..."
- ISSUE-id (or QA-id) prefix when the branch has one
- URL on its own line, no Markdown brackets — Slack unfurls bare URLs cleanly
- **Exactly one URL per message.** Two bare URLs on adjacent lines collapse into a single combined unfurl in Slack — the second link is lost. Additional PRs each get their own message (see Multiple or companion PRs).
- No emoji, no greetings, no signature

## What counts as a caveat (thread)

**The warrant test:** thread it only if a teammate must DO or KNOW it and the PR itself wouldn't tell them. Default to no caveats — most PRs don't need any.

Warranted:
- Feature flags and their default state
- Required follow-up actions (migrations, configs, manual ops)
- Known limitations or follow-up tickets that block relying on the change
- Dependencies on other PRs
- Reviewer hint *only* when the diff is large enough that pointing at the load-bearing file genuinely saves time

Do NOT include (these are nitpicks, not caveats):
- Apologies, hedges, or self-deprecation ("sorry it's big")
- Anything the diff already shows ("changed 12 files", renames, reformats, moved methods)
- Patch/transitive dependency bumps, comment/KDoc tweaks
- Reviewer hints on small or single-purpose PRs
- Reasoning the PR description already covers
- A "hint" that is really several nitpicks bundled together to look load-bearing

## Approval gate — non-negotiable

Even when the user has pre-authorized announcement, show the composed message and channel **before** sending. The Slack tools are not reversible; a wrong channel or typo is visible to everyone immediately. This step costs the user one reply and prevents the failure mode of posting half-baked summaries.

## Common mistakes

- **Posting without showing the plan first** — "I'll just send it, they said to post" is wrong. Always show.
- **Folding caveats into the headline** — makes the unfurl noisy, defeats the one-sentence rule.
- **Silent channel guesses** — if memory has no entry, propose + confirm + save; don't pick and post.
- **Re-announcing** — if you already posted earlier in the session, stop.
- **Including the PR description verbatim** — the link unfurls; the headline is the *hook*, not a copy of the body.
- **Threading trivia** — only post a thread reply if it clears the warrant test (a DO-or-KNOW a teammate wouldn't get from the PR). Default to no caveats; renames, reformats, dep bumps, and small-PR "reviewer hints" don't qualify.
- **Two URLs in one message** — companion PRs stacked as bare URLs on adjacent lines collapse into one unfurl and the second link is lost. One URL per message; extra PRs go as their own thread replies.

## Red flags — stop and re-check

- About to call `slack_send_message` without having shown the plan → STOP, show it
- About to post to a channel you picked from memory without verifying it still exists → fine, but if Slack returns "channel not found", ask the user, don't search and pick another silently
- Any caveat that survives because you bundled nitpicks (renames, reformats, dep bumps) into one "reviewer hint" → that is over-threading; drop it. If each item alone wouldn't clear the warrant test, the bundle doesn't either.
- About to write a thread reply you can't tie to a concrete DO-or-KNOW for a teammate → STOP, leave it out
- About to send a message body containing two or more URLs → STOP, split them; one URL per message or the unfurls merge
- Caveat list is longer than 4 items → likely conflating "things to mention" with "things the reviewer must know"; trim
