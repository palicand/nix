---
name: migrate-gitlab-ci
description: Use when converting a BKBN repo's GitLab CI to GitHub Actions — porting .gitlab-ci.yml, cloudbuild.yaml, or Cloud Build triggers; writing .github/workflows for a bkbn-com repo; or wiring release/deploy during the GitLab→GitHub migration (epic ISSUE-2295).
---

# Migrate GitLab CI to GitHub Actions (BKBN)

## Overview

Porting guide for converting BKBN repos from GitLab CI (+ Cloud Build) to GitHub Actions. The architecture is **decided** — conversions implement it, they don't re-litigate it. Modernize, don't transliterate: map intent, not YAML shape.

**Read `porting-reference.md` in this skill directory for the full concept-mapping tables and recipes before writing any workflow.**

## Architecture invariants (decided — do not deviate)

1. **Runners: GitHub-hosted** (`ubuntu-latest`). ARC/self-hosted was abandoned (ISSUE-2299 aborted). No `runs-on: self-hosted`, no runner labels.
2. **GCP auth: Workload Identity Federation only**, via the `bkbn-com` pool/provider in `infrastructure-gcp` (`modules/ci_cd/github_wif.tf`). **That pool is a deliverable of the baseline (ISSUE-2300), not pre-existing** — today the file holds only the legacy `bkbnlab` pool (different org; ignore it, never extend it). Never SA JSON keys, never ad-hoc per-repo pools. Wire workflows to org/repo vars (`GCP_WIF_PROVIDER`, `GCP_DEPLOY_SA`) so they bind once the pool merges.
3. **Images and artifacts: Artifact Registry** (existing repos, e.g. `europe-west1-docker.pkg.dev/.../bkbn-k8s/...`). Not GHCR. Keep existing image names/tags/namespaces unchanged.
4. **Shared logic lives in `bkbn-com/infra-github`** as reusable workflows + composite actions, consumed via `uses: bkbn-com/infra-github/.github/workflows/<name>.yml@v1` with `secrets: inherit`. Consumer repos get thin callers. Hand-roll only in repos with trivial CI (lint/test only, no deploy). **Ordering: the library merges first** — a consuming repo's callers cannot go green until `infra-github@v1` exposes the workflows they reference; sequence conversions on that dependency. Trivial repos don't wait.
5. **The release-branch model is preserved.** Do NOT replace it with `workflow_dispatch` deploys:
   - Manual "cut release" job on master pushes `release-<env>[-<app>]/<YYYY-MM-DDThh-mm>` (+ tag `production[-<app>]-<ts>` where the repo tags today).
   - A workflow triggered `on: push: branches: ['release-production**']` (match the repo's exact pattern) does the real build + deploy — this replaces the Cloud Build trigger.
   - The release workflow **creates a GitHub Release AND a GitHub Deployment** (see reference for the recipe).
   - Repos that deploy only from master keep deploying from master.
   - Third case — **dev release branches**: some repos' dev trigger fires on `master` OR `release-development[-<app>]/**` (manual "Deploy to DEV" cuts dev branches for WIP testing). Port as one dev-deploy workflow watching both patterns, mirroring the TF dev-trigger regex exactly.
   - **Exception:** backend-platform and frontend-platform release branches stay watched by Cloud Build until their wave says otherwise — do not touch their triggers.
6. **One deploy path at a time.** Moving a repo's deploy to Actions and deleting its Cloud Build trigger (in `infrastructure-gcp/modules/ci_cd/`) ship as one paired change. Never leave both watching the same branch pattern.
7. **Replicate the existing deploy mechanism.** If Cloud Build does `gke-deploy`/`kubectl set image`, Actions does the same via WIF + `get-gke-credentials`. Do not introduce ArgoCD/GitOps or change deploy semantics mid-migration.

## Conversion workflow (per repo)

1. **Inventory:** read `.gitlab-ci.yml` + every `include:` source (`infrastructure-gcp/gitlab-ci/`, `infrastructure-gitlab-ci/`), all `cloudbuild*.yaml`, AND grep `infrastructure-gcp/modules/ci_cd/*.tf` for this repo's triggers — the Cloud Build side IS part of the pipeline. Note branch regexes, substitutions, scheduled pipelines, and GitLab CI variables consumed (`$VAR` not defined in-file = project/group variable to map). Watch for **fake variables**: GitLab does not shell-expand values, so `VAR: $(date ...)` is a literal no-op string — don't dutifully map those; port the intent.
2. **Map each job** using the tables in `porting-reference.md`. Decide: library caller vs hand-rolled (invariant 4).
3. **Write workflows** under `.github/workflows/`. PR checks on `pull_request`; master jobs on `push: branches: [master|main]`; release per invariant 5.
4. **Pair the infra change:** if the deploy path moves, write the `infrastructure-gcp` PR deleting the trigger (+ adding the repo's WIF SA/bindings if missing) alongside.
5. **Validate on GitHub:** author on a normal GitHub feature branch, open a PR, and verify its Actions checks. Merge only after the required checks pass. Also validate default-branch and release triggers with `actionlint` where they cannot safely be exercised from the PR.
6. **Dual-run:** CI (build/test) may run green on both systems until cutover; deploy must not (invariant 6).

## Common mistakes (all observed in baseline testing)

| Mistake | Correction |
|---|---|
| Replacing release branches with `workflow_dispatch` + environment picker | Keep the release-branch cut job + branch-pattern-triggered release workflow (invariant 5) |
| Creating only a GitHub Release (or only on master) | Release workflow creates Release **and** Deployment, triggered by the release branch |
| Hand-rolling per-repo copies of build/test/coverage logic | Thin callers to `infra-github@v1`; hand-roll only trivial repos |
| Porting the `report-generator`/Cobertura image pipeline verbatim | Kover/JaCoCo XML → `madrapps/jacoco-report` PR comment (see reference) |
| Leaving "double deploy during mirror window" as an open question | Resolved by design: paired trigger removal, one deploy path (invariant 6) |
| Wiring WIF against the `bkbnlab` pool or minting a new pool per repo | Use the canonical `bkbn-com` pool/provider from `infrastructure-gcp` |
| Switching deploy mechanism (e.g. kubectl → ArgoCD) "while we're at it" | Replicate what Cloud Build did; mechanism changes are separate tickets |
| Assuming `[skip ci]` works everywhere | GitHub honors it on `push` only, not `pull_request` — usually acceptable, note it in the PR |
| Enabling gitleaks full-history scan and failing on legacy hits | Scan the PR diff / shallow range; committed-secret cleanup is ISSUE-2297, not your PR |

## Definition of done (per repo)

- [ ] Actions green on a real PR and on default-branch push — for library-consuming repos this requires the infra-github library merged and tagged first
- [ ] Release path proven per invariant 5, or explicitly N/A (master-only repo) or deferred (be/fe exception)
- [ ] No SA keys in secrets; no GitLab CI variable left unmapped (each → org/repo/env secret, var, or retired)
- [ ] Paired infrastructure-gcp PR merged if a deploy moved
- [ ] GitLab CI kept green (dual-run) unless the ticket says otherwise
