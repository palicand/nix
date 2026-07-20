---
name: bkbn-my-queue
description: >-
  Analyze the current user's assigned tickets in the BKBN Notion Master Database and render a
  filterable "work queue" dashboard grouped by pipeline stage and project. Use this whenever the
  user asks about "my tickets", "my work queue", "my queue", "what's ready to develop", "what
  should I pick up next", "what's not started", "what's stuck / pending / waiting", "my standup",
  "what's assigned to me", "what's in review / awaiting QA", or asks to see their BKBN tasks
  grouped/bucketed by status — even if they don't say "dashboard" or "Notion". Also the target of
  any scheduled/daily run of the BKBN work-queue report. Prefer this over ad-hoc Notion queries
  whenever the goal is a personal status readout of the user's own Master Database tickets.
---

# BKBN — my work queue

Produces a personal status readout of the current user's assigned tickets from the BKBN Notion
**Master Database**: every open ticket bucketed by pipeline stage (ready to develop, stuck,
pending grooming / review / QA / deploy, in progress), grouped by project, and rendered as an
interactive Artifact dashboard plus a short terminal summary.

## Why the bucketing matters (read this first)

The Notion `Status` field has 17 values. Their pipeline order is:

`New → Triage → Tech Review • Needed → Tech Review • Started → Backlog → Doing → Code Review → Merged → Dev-ready → Testing → Approved → Deployed` (terminal: `Archived`, `Aborted`).

Two readings people get wrong — get them right:

- **`Backlog` is the real "ready to develop" queue** — groomed and ready to pull, not yet started. It's the only to-do-group status that's actually dev-ready. `New` / `Triage` / `Tech Review` sit *before* grooming, so they are **not** ready — they're pending triage/design.
- **`Dev-ready` means the developer is DONE and it's awaiting QA/testing** — a *late* stage, not a starting one. Never present it as "ready to pick up."

## Steps

### 1. Resolve identity and data source

- Confirm the connected Notion user with `notion-fetch` id `"self"` (or `notion-get-users` `user_id: "self"`). Record the user id and name.
- Master Database data source: `collection://253f14ae-55e2-8063-91bd-000ba1b72d51`.
  (If a run ever fails because the id moved, open the "Work work" page or search Notion for
  "Master Database" and re-read the `<data-source url=…>` tag.)

### 2. Query the user's open tickets

Run one SQL query via `notion-query-data-sources` (fill in the real user id):

```sql
SELECT "userDefined:ID" AS id, "Name", "Status", "Workload", "Type", "Team", "Category",
       "Effort", "Product Components", "Parent", "Blocked by", "Blocking",
       url, "date:Ticket Timeline:start" AS timeline_start, "Updated"
FROM "collection://253f14ae-55e2-8063-91bd-000ba1b72d51"
WHERE "Assignee(s)" LIKE ?           -- params: ['%<USER_ID>%']
  AND "Status" NOT IN ('Approved','Deployed','Archived','Aborted')
ORDER BY "Status"
```

### 3. Bucket each ticket by stage

| Status | Bucket key |
|--------|-----------|
| `Backlog` | `ready` |
| `New`, `Triage`, `Tech Review • Needed`, `Tech Review • Started` | `grooming` |
| `Doing` | `progress` |
| `Code Review`, `Design Review` | `review` |
| `Merged` | `deploy` |
| `Dev-ready`, `Testing` | `qa` |
| `Blocked`, `On Hold` | `stuck` |

**Staleness override:** any ticket in `progress` or `review` whose `Updated` is more than **30 days**
before today moves to the `stuck` bucket and gets `flag: "stale"` with `flagText` like `"Stale ~5mo"`.
This is what surfaces work that has silently stalled in review.

### 4. Derive a "project" label

There is no `Project` field. Pick the first available, in this precedence, and keep it concise:

1. **Parent** epic name — fetch parent page titles by querying the same data source for the parent
   `url`s (`SELECT "userDefined:ID", "Name", url FROM … WHERE url IN (…)`). Shorten long epic titles.
2. **Product Components** — resolve names from `collection://294f14ae-55e2-80cf-80a4-000bcd940368`
   (`SELECT "Name", url FROM …`); join multiple with `" / "`.
3. **Category**, then **Team**, else `"Unassigned"`.

Where several tickets clearly belong to one initiative (e.g. ArgoCD, preview environments,
observability), it's fine to normalize them to one short shared label so the Project grouping reads well.

### 5. Optional per-ticket flags

Set `flag` (+ optional `flagText`) when it adds signal — keep it sparing:
`due` (has a near-term `timeline_start`, e.g. `flagText:"Due Jul 10"`), `security` (Type/Name implies
credential/IAM/secret work), `stale` (from step 3), `epic` (`Workload = 🗓️ Epic`),
`win` (`Effort = ⚡️ Quick-win`), `bug` (`Type = 🐞 Bug / Product Issue`).

### 6. Render the dashboard

- Read `assets/dashboard-template.html` (sibling to this file).
- Replace `__TICKET_DATA__` with a JSON array of ticket objects, each:
  `{ id, title, status, bucket, project, team, url, flag?, flagText? }`
  — `status` is the raw Notion status (e.g. `"Backlog"`, `"Code Review"`, `"Dev-ready"`);
  `bucket` is the key from step 3; `url` is the full `app.notion.com` URL from the query.
- Replace `__ASSIGNEE__` with the user's name and `__DATE__` with today's date (`YYYY-MM-DD`).
- Write the filled file to the scratchpad (or cwd) and publish with the `Artifact` tool
  (favicon `🗂️`). On repeat/scheduled runs, redeploy to the **same URL** by passing the same
  `file_path` (or the prior artifact `url`) so the user keeps one stable link.

### 7. Terminal summary

Also print a compact text summary so a headless/scheduled run is useful without opening the page:
per-bucket counts, then the **Ready to develop** list (id + title + project), and call out anything
`stuck` or newly `security`/`due`-flagged. Keep it terse.

## Notes

- Read-only. Never write to Notion.
- If the Notion MCP connector is unavailable (can happen in headless/cron runs that lack the
  interactive claude.ai auth), say so plainly and stop — do not fabricate ticket data.
- Related: the `bkbn-ticket-audit` skill cross-checks these Notion statuses against real GitHub PR
  state (e.g. "Code Review in Notion but the PR already merged"). Offer it when the user wants truth
  from GitHub rather than from Notion.
