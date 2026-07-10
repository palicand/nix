---
name: bkbn-implement-tickets
description: Use when implementing multiple BKBN Notion tickets in one session — parent ticket with sub-items, list of ticket URLs, or "my assigned tickets ready for development" (Notion Status between Backlog inclusive and Merged exclusive). Drives the full superpowers workflow plus team-coordinated execution; produces one GitLab MR per ticket.
---

# BKBN Implement Tickets

## Overview

Take one or more BKBN Notion tickets and ship them as GitLab MRs in a coordinated parallel run.

**Core principle: a Notion ticket and its referenced spec are the *what*. A plan is the *how*. Never dispatch implementation agents until every ticket has a plan committed to its branch.**

Violating the letter of the workflow is violating the spirit of the workflow.

## When to use

Triggers — the user:
- Pastes a parent Notion ticket URL and asks you to implement it and its child tickets
- Pastes a list of ticket URLs to implement
- Says "implement my queue", "work through my backlog", "all my assigned tickets ready for dev"
- Says any phrase that combines "Notion tickets" + "implement / build / ship"

Do NOT use this skill for:
- Single-ticket work (use `/bkbn-feature-branch` + writing-plans + manual implementation)
- Non-BKBN repos
- Research-only tickets (no code output)
- Documentation-only tickets (different workflow)

## The non-negotiable workflow

```
Step 1  Gather tickets        (notion-fetch + notion-search)
Step 2  Filter already-MR'd   (glab mr view per linked MR)
Step 3  Build dep graph       (read referenced specs)
Step 4  Plan per ticket       (REQUIRED SUB-SKILL: superpowers:writing-plans)
        ─── GATE: every plan committed to its branch ───
Step 5  Create the team       (TeamCreate — NOT bare Agent calls)
Step 6  Spawn teammates       (Agent with team_name + name; teammate uses superpowers:executing-plans)
Step 7  Collect MR URLs       (relay to user as teammates report)
Step 8  Shutdown + cleanup    (SendMessage shutdown_request → TeamDelete)
```

**Every step is a gate. None of them are optional. If you find yourself thinking "I can skip step N because…" — see the rationalization table below.**

## Step 1 — Gather tickets

Three input forms:

**Parent ticket URL.** `mcp__claude_ai_Notion__notion-fetch` the parent. Read its `Sub-items` property — that's the list of child URLs. Fetch each child in parallel (single message, multiple tool calls) so you have full ticket bodies for planning.

**List of URLs.** Fetch each in parallel.

**"My assigned tickets ready for dev."** Query the Master Database. The user's email is in the auto-memory `userEmail` (e.g. `a.palicka@bkbn.com`); resolve to a Notion user via `notion-search` with `query_type: user`. Then `notion-search` with `query_type: internal` and `data_source_url: collection://253f14ae-55e2-8063-91bd-000ba1b72d51` (BKBN Master Database). Filter by assignee + Status not in {`New`, `Done`, `Merged`, `Cancelled`}.

Ready statuses (verify against the actual workspace's Status field): `Backlog`, `Doing`, `In Review`, `Code Review`, `QA`.

## Step 2 — Filter already-MR'd tickets

Each Notion ticket has a `GitLab MRs` property listing related MR URLs. For each:
- Run `glab mr view <number>` in the right repo
- `Merged` → skip the ticket entirely
- `Opened` → ask the user: "skip / write retroactive plan only / redo from scratch"
- `Closed` (no merge) → treat as "no MR"

If the user has not stated a preference, default to **skip**. Do not silently overwrite open MRs.

## Step 3 — Build dependency graph

Each ticket's body references a spec (typically `docs/superpowers/specs/...md` in `infrastructure-gcp` or the relevant repo). Read those specs to learn:
- Cross-ticket dependencies (e.g. ticket B's chart consumes ticket A's image)
- Repos touched per ticket (cross-cutting tickets become multiple MRs across repos)
- Whether tickets stack (one ticket's branch is another's base)

User's stated convention for stacked branches: "If the work depends on something else, you base it on the parent branch, then gradually as things are merged in GitLab we will rebase." Honor this — don't try to rebase pre-merge.

Wire the dependency graph into the team's task list using `addBlockedBy` so dependent teammates can't claim work before prerequisites push.

## Step 4 — Plan per ticket (REQUIRED SUB-SKILL)

**REQUIRED SUB-SKILL:** Invoke `superpowers:writing-plans` for each ticket. Plans are deliverables, not optional documentation.

Plan location: `<repo>/docs/superpowers/plans/YYYY-MM-DD-<slug>.md`. (If the repo has `docs/` gitignored, force-add the plan with `git add -f` and flag the .gitignore for the user to fix later.)

Plan requirements (per superpowers:writing-plans):
- Frontmatter-style header (Goal, Architecture, Tech Stack, Spec, Worktree)
- File structure section — exact paths to create/modify
- Bite-sized tasks with code blocks, validation commands, exact commit messages
- Self-review section at the end

**Worktree per ticket** (created BY YOU before plan writing, so the writer agent has a place to commit):

```bash
cd <repo>
git fetch origin
git worktree add -b task/issue-<id>/<slug> .worktrees/<id> <base-branch>
```

Branch convention: from the ticket's `Branch Command` Notion field (typically `task/issue-<id>/<description>` or `feature/issue-<id>/<description>`).

For multi-ticket epics with shared context, **one combined plan with sub-projects (A, B, C…)** is acceptable — but each sub-project must be self-contained (own branch, own MR, own validation gate) **AND must contain at least 3 numbered tasks, each with its own code block and its own validation command**. Anything thinner means you're collapsing 9 tickets into 9 one-liners — write separate plans instead.

**STOP gate after Step 4:** open every plan file. Search for `TBD`, `TODO`, `<placeholder>`, "implement later". If any task lacks a code block or validation command, fix the plan before continuing. The writing-plans skill documents what counts as a placeholder — none of those are allowed. Additionally check **decomposition density**: every sub-project must have ≥3 tasks; each task must have its own validation command (not "see Task N" reuse). If a sub-project has <3 tasks or shared validation across tasks, you've built the plan for an audience that doesn't exist — split or expand.

## Step 5 — Create the team

```
TeamCreate({
  team_name: "<short-descriptive-name>",
  description: "<one-line: what the team is doing>",
  agent_type: "team-lead"
})
```

**Use TeamCreate. Do not use bare `Agent({run_in_background: true})` calls for multi-ticket work.** Bare Agent calls are async dispatch; they have no shared task list, no peer messaging, no idle visibility, and no coordinated shutdown. Teams give you all four.

Once the team exists, create one Task per ticket / sub-project via `TaskCreate`. Set `addBlockedBy` per the dependency graph from Step 3.

## Step 6 — Spawn teammates

For each ticket / sub-project:

```
Agent({
  team_name: "<team>",
  name: "engineer-<short-id>",
  subagent_type: "general-purpose",
  run_in_background: true,
  prompt: <self-contained brief — see template below>
})
```

Teammate prompt MUST include:
1. The Task ID to claim from the shared task list
2. The plan file path (already committed in Step 4)
3. The worktree path (already created in Step 4)
4. **REQUIRED SUB-SKILL for the teammate:** invoke `superpowers:executing-plans` and follow it task-by-task, committing per task
5. How to commit and create the MR — prefer `/bkbn-commit` and `/bkbn-mr` slash skills if available; fall back to `git commit` + `glab mr create`
6. Instruction to `SendMessage` the team-lead with the MR URL on completion
7. For dependent sub-projects: instruction to also `SendMessage` the team-lead the moment the branch is pushed (so the lead can spawn the next teammate in the chain)

For dependent sub-projects, **do not pre-spawn**. Spawn the dependent teammate only after the upstream teammate confirms its branch is pushed. Otherwise the dependent's worktree-add will fail.

## Step 7 — Collect MR URLs

As teammates SendMessage with MR URLs:
- `TaskUpdate` the corresponding task to `completed` with `metadata.mr_url`
- Acknowledge to the user with the running list of MRs

Stale idle pings from teammates are normal — do not chase them. They mean "I'm done with my turn; ping me if you need anything." See the team docs.

## Step 8 — Shutdown + cleanup

When all teammates have reported MR URLs and gone idle:
1. SendMessage each teammate a `shutdown_request`
2. Wait for `teammate_terminated` notifications
3. `TeamDelete` to remove the team directory and task list
4. Final report to the user: every MR URL, ideally as a stack diagram for stacked branches

## Anti-pattern table — STOP and reset if you catch yourself thinking these

| Rationalization | Reality | Reset action |
|---|---|---|
| "The spec is detailed enough; agents can implement directly from it" | Spec = what; plan = how. They are not interchangeable. | Stop. Restart from Step 4. Write a plan per ticket. |
| "Individual `Agent` calls in parallel ARE a team" | Async dispatch ≠ coordination. No shared state, no peer messaging, no idle visibility, no orderly shutdown. | Stop. Restart from Step 5. `TeamCreate` first, then spawn as teammates. |
| "Auto mode says 'prefer action over planning'" | Auto mode applies *within* the workflow. Auto mode does not authorize skipping steps of the workflow. | Stop. Restart from Step 4. Auto mode resumes after the plan is committed. |
| "I have prior session context; I can shortcut" | New tickets need new plans. Earlier work doesn't transfer. | Stop. Plan from scratch per ticket. |
| "Brainstorming and writing-plans are skills, not gates" | Both are gates. Each plan is a literal artifact (a committed file) required before any teammate spawn. | Stop. Treat each plan as a deliverable. |
| "I'll write a retroactive plan after the implementation lands so we can move fast" | Retroactive plans are documentation, not planning. They miss the *why* and lose the chance to design before coding. | Stop. Plan first, implement second. Always. |
| "Just for this one ticket I'll skip the plan" | Letter ≠ spirit only when the rule is bad. The rule is good. | Stop. Plan it. |
| "The plan would just repeat the spec" | If the plan is the spec verbatim, the spec is missing decomposition into bite-sized tasks. Add the decomposition. | Stop. Decompose into 2-5 minute tasks. |
| "I'll combine 9 tickets into one plan with 9 one-task sub-projects" | That's nine one-liners, not a plan. Sub-projects need ≥3 tasks each with their own validation. | Stop. Either expand each sub-project to ≥3 tasks or write separate plans. |

## Red flags — these mean reset, not "interesting observation"

- I am about to call `Agent` and have not yet called `TeamCreate` (for multi-ticket work)
- I have not invoked `superpowers:writing-plans` for a ticket I'm about to dispatch
- I am thinking "the design spec covers it"
- I am thinking "auto mode lets me skip the plan"
- I am dispatching from in-context muscle memory of how I did similar work earlier in the session
- A plan file does not exist for a ticket whose teammate I'm about to spawn

**Each red flag means: stop, restart from Step 4 of the workflow above. No exceptions.**

## Pre-flight checklist (run BEFORE every `Agent` invocation in this skill)

- [ ] Notion tickets fetched and filtered? (Steps 1, 2)
- [ ] Dependency graph established and reflected in task `addBlockedBy`? (Step 3, 5)
- [ ] Plan committed for every ticket I'm about to dispatch? (Step 4 + STOP gate)
- [ ] `TeamCreate` invoked? (Step 5)
- [ ] Teammates being spawned with `team_name` + `name`, not bare Agent? (Step 6)

If any answer is "no" — **do not call Agent**. Restart from the failed step.

## Reference: Notion query for "my assigned tickets ready for dev"

BKBN Master Database collection: `collection://253f14ae-55e2-8063-91bd-000ba1b72d51`

```
1. Resolve user from email:
   notion-search({ query_type: "user", query: "<userEmail from auto-memory>" })

2. Query Master Database for assigned-and-ready tickets:
   notion-search({
     query_type: "internal",
     query: "tickets assigned to me",
     data_source_url: "collection://253f14ae-55e2-8063-91bd-000ba1b72d51",
     filters: { /* assignee match — see workspace schema */ }
   })

3. Post-filter results in Claude (the Notion API doesn't expose Status filtering
   directly via search): drop tickets whose Status is in {New, Done, Merged, Cancelled}
   and whose Type is Documentation-only.
```

If the workspace adds a new Status value, add it to the filter list explicitly. Don't guess.

## Reference: BKBN conventions

- Branch: `task/[ISSUE-XXXX] <description>` from the ticket's Branch Command field
- Worktree: `<repo>/.worktrees/<id>/`
- Commit message: short title only, no body (squash-merge collapses these; only the MR description matters). Exception: commits direct on master/main can have a body.
- MR body: `## Summary` (1-3 bullets), `## Ticket` (Notion link + parent), `## Test plan` (markdown checklist), `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer
- Slash skills available to teammates: `/bkbn-commit`, `/bkbn-mr`, `/bkbn-feature-branch`, `/bkbn-fix-ci`, `/bkbn-fix-review`

## Common mistakes

| Mistake | Fix |
|---|---|
| Spawning a teammate before its plan file exists | Hard-block on Step 4 STOP gate. Plan must exist *and be committed* before teammate spawn. |
| Pre-spawning dependent teammates with `addBlockedBy` and hoping they wait | Don't. Spawn the dependent teammate AFTER the upstream branch is pushed. The upstream teammate's SendMessage is your trigger. |
| Forgetting to set `addBlockedBy` on dependent tasks | Wire it in Step 5. The task list is the record of dependencies. |
| Targeting `--target-branch master` for a stacked MR | Use `--target-branch <upstream-branch>` so the diff shows just this MR's delta. Document the rebase requirement in the MR body. |
| Skipping the retroactive plan for an open MR (Step 2 case) | If the user opted to add an open MR to the plan-only batch, write the retroactive plan and push it as an additional commit on the existing branch. |
| Burning the cache pinging idle teammates | Ignore stale idle notifications. They mean "available for work" not "needs response." |

## Real-world impact

Failure mode this skill prevents (observed during the ephemeral preview environments rollout, May 2026):

- 9 tickets across 3 repos
- Without this skill: 7 of 9 dispatched as bare `Agent` calls, no plans, design spec used as substitute. 2 of those agents stalled on watchdog timeout. Retroactive plan-writing required afterward — extra full team cycle.
- With this skill: 9 of 9 should ship as planned-then-executed, in one parallel team-coordinated pass.

The retrospective on that session is what generated this skill. The rationalizations in the table above are verbatim from that session.

## When NOT to use

- Single ticket — use `/bkbn-feature-branch` + writing-plans manually, no team needed
- Non-BKBN repos — no Notion ticket, no GitLab pipeline conventions
- Research/spike tickets — different workflow (brainstorming-heavy, low code output)
- Tickets with manual-only work (e.g. Auth0 dashboard tweak) — describe in MR body, no team
