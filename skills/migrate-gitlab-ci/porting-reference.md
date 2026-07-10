# Porting reference: GitLab CI → GitHub Actions (BKBN)

Companion to `SKILL.md`. Tables map GitLab CI concepts to their Actions equivalents; recipes cover the BKBN-specific machinery.

**The recipes below are the bodies of the reusable workflows in `infra-github`** — consumer repos call them via thin callers (SKILL.md invariant 4); only trivial repos inline them. Action version pins (`@v3`, `@v5`, …) are illustrative — the library author must verify current majors against the marketplace before committing.

## Concept mapping

| GitLab CI | GitHub Actions |
|---|---|
| `include: project: bkbn/...` | `uses: bkbn-com/infra-github/.github/workflows/<x>.yml@v1` (reusable workflow) |
| `extends: .template` / YAML anchors | Reusable workflow (whole job) or composite action (steps) in infra-github |
| `stages:` + `needs:` | `jobs.<id>.needs:` (there are no stages; needs is the only ordering) |
| `rules: if: $CI_MERGE_REQUEST_ID` | `on: pull_request` |
| `rules: if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH` | `on: push: branches: [master]` (use the repo's actual default) |
| `except: [master]` | job only in the `pull_request`-triggered workflow |
| `rules: ... when: manual` | `workflow_dispatch`, or `environment:` with required reviewers (deploy gates) |
| `workflow: rules:` (pipeline-level) | per-workflow `on:` filters + `concurrency:` |
| `resource_group: X` | `concurrency: { group: X, cancel-in-progress: false }` |
| `interruptible: true` | `concurrency: cancel-in-progress: true` (group per ref) |
| `allow_failure: true` | `continue-on-error: true` |
| `image: <docker>` | `container: image:` on the job, or plain `ubuntu-latest` + setup actions (preferred: `actions/setup-java`, `setup-node`; AR images need WIF auth first) |
| `services: docker:dind` | Usually unnecessary — hosted runners have Docker. Testcontainers etc. work natively. Delete the DOCKER_HOST/TLS variables. |
| `cache:` (gradle/yarn/sonar) | `gradle/actions/setup-gradle`, `actions/setup-node` with `cache: yarn`, or `actions/cache` |
| `artifacts: paths:` | `actions/upload-artifact` / `download-artifact` (between jobs) |
| `artifacts: reports: coverage_report` | PR comment action + job summary (see Coverage recipe) |
| coverage regex (`coverage: '/.../'`) | `$GITHUB_STEP_SUMMARY` line + PR comment action (no native badge) |
| `secret_detection` template | `gitleaks/gitleaks-action` or gitleaks binary on the PR diff range only |
| `release-cli` / `Create GL Release` | `gh release create` or `softprops/action-gh-release` (see Release recipe) |
| `environment: production` | `environment: production` on the job (create GitHub Environments; protection rules replace `when: manual` where appropriate) |
| Scheduled pipelines (`only: schedules`) | `on: schedule: cron:` (timezone is UTC; GitLab scheduled-pipeline variables become workflow inputs/vars) |
| Project/group CI variables | org/repo/environment **secrets** (sensitive) or **vars** (plain); GitLab environment *scopes* → GitHub Environments (ISSUE-2305 mapping doc) |
| `CI_REGISTRY*` (GitLab registry) | Artifact Registry + WIF (never GHCR) |
| `$CI_PIPELINE_SOURCE == "merge_request_event"` | `github.event_name == 'pull_request'` |
| `[skip ci]` in commit message | Native on `push` only; `pull_request` runs regardless |

## WIF auth recipe

Canonical pool/provider live in `infrastructure-gcp` (created by the keystone ticket). Per deploying repo: a deploy SA with minimal roles + `roles/iam.workloadIdentityUser` binding scoped to `principalSet://...attribute.repository/bkbn-com/<repo>`.

```yaml
permissions:
  contents: read
  id-token: write        # REQUIRED for OIDC
steps:
  - uses: google-github-actions/auth@v3
    with:
      workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}   # org-level var
      service_account: ${{ vars.GCP_DEPLOY_SA }}                 # env-level var — see note
  - uses: google-github-actions/setup-gcloud@v3
  # Docker/Jib pushes to AR:
  - run: gcloud auth configure-docker europe-west1-docker.pkg.dev --quiet
```

For GKE: `google-github-actions/get-gke-credentials@v3` with the cluster/location the repo's cloudbuild.yaml used, then the same `kubectl`/`gke-deploy`/Helm commands Cloud Build ran.

**Environment-scoped secrets/vars resolve only inside the job that declares `environment:`** — and a caller job cannot set `environment:` on a reusable-workflow call. So the `environment:` line and every env-scoped var/secret read (`GCP_DEPLOY_SA`, cluster names, …) live INSIDE the reusable workflow (parameterized by an `environment` input); callers pass plain inputs, never env-scoped values via `with:`.

## Release recipe (invariant 5 in SKILL.md)

Two workflows replace `Deploy.gitlab-ci.yml` + `ReleaseBranch/Release.gitlab-ci.yml` + the Cloud Build trigger:

**1. `cut-release.yml`** — manual, master only. Replaces `.deploy:production[_with_tagging]`:

```yaml
on:
  workflow_dispatch:      # replaces `when: manual` on master
jobs:
  cut:
    if: github.ref == 'refs/heads/master'
    runs-on: ubuntu-latest
    permissions: { contents: write }
    steps:
      - uses: actions/checkout@v5
      - run: |
          TS=$(date '+%Y-%m-%dT%H-%M')
          BRANCH="release-production${APP_SUFFIX:+-$APP_SUFFIX}/$TS"
          git checkout -B "$BRANCH" && git push -u origin "$BRANCH"
          # keep the tag if the repo tags today (production[-app]-<ts>)
          git tag "production${APP_SUFFIX:+-$APP_SUFFIX}-$TS" master && git push origin --tags
```

Caveat: during the mirror window this pushes to **GitLab** (source of truth), so cut-release stays a GitLab CI job until cutover if the repo still has GitLab CI; the Actions version activates at cutover. The **watcher** below moves to Actions immediately (the mirror delivers the branch).

**2. `release.yml`** — the watcher. Replaces the Cloud Build trigger:

```yaml
on:
  push:
    branches: ['release-production**']   # match the repo's exact TF trigger regex
concurrency: { group: release-production, cancel-in-progress: false }
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production              # GitHub Environment: secrets, protection, URL
    permissions: { contents: write, id-token: write, deployments: write }
    steps:
      # WIF auth (above) → build (Jib/docker/yarn, same tags as cloudbuild.yaml) → deploy (same mechanism)
      - uses: chrnorm/deployment-action@v2        # GitHub Deployment + status
        id: gh-deploy
        with: { token: '${{ github.token }}', environment: production, ref: '${{ github.ref }}' }
      # ... build + deploy steps ...
      - uses: chrnorm/deployment-status@v2
        if: always()
        with:
          token: '${{ github.token }}'
          deployment-id: ${{ steps.gh-deploy.outputs.deployment_id }}
          state: ${{ job.status == 'success' && 'success' || 'failure' }}
  release:
    needs: deploy
    runs-on: ubuntu-latest
    permissions: { contents: write }
    steps:
      - uses: actions/checkout@v5
        with: { fetch-depth: 0 }
      - run: |
          PREV=$(git tag -l 'production*' --sort=-creatordate | sed -n 2p)
          gh release create "$TAG" --target "$GITHUB_SHA" --generate-notes \
            ${PREV:+--notes-start-tag "$PREV"}
        env: { GH_TOKEN: '${{ github.token }}' }
```

Per-service monorepos (backend-services): one watcher per service branch pattern (`release-production-<svc>/**`) or one workflow extracting the service from `github.ref`; Release title/tag prefixed per service, mirroring today's `Create GL Release - <svc>` jobs.

Master-only repos (no release branches): skip `cut-release.yml`; the master `push` workflow deploys (dev today) and — where the repo releases from master — creates the Release/Deployment there. Keep it as-is; do not invent release branches.

## Coverage recipe (Kotlin/Kover or JaCoCo)

Replace the `report-generator`/`jacoco2cobertura` image jobs:

```yaml
- uses: madrapps/jacoco-report@v1.7.2      # accepts JaCoCo-format XML (Kover emits it)
  with:
    paths: '**/build/reports/kover/report.xml'   # or jacoco/test/jacocoTestReport.xml
    token: ${{ secrets.GITHUB_TOKEN }}
    min-coverage-overall: 0                       # match current thresholds (usually none)
```

Verify the actual XML output path from the repo's gradle config before assuming — GitLab used project vars (`$REPORT_PATHS`) that don't exist in-repo.

## Sonar / OWASP / Claude review

- **Sonar:** `SonarSource/sonarqube-scan-action` (SonarCloud), `SONAR_TOKEN` org secret, `fetch-depth: 0`. GitLab gated it manual — keep it non-blocking (`continue-on-error` or separate manual workflow).
- **OWASP:** `./gradlew dependencyCheckAnalyze` gated by repo var `RUN_OWASP_CHECKS`, scheduled (`on: schedule`) not per-PR, `continue-on-error` for the full check. NVD API key as secret speeds it up.
- **Claude review:** port of `claude-code-review.yml` — use the official `anthropics/claude-code-action` on `pull_request` instead of the hand-rolled glab script; `ANTHROPIC_API_KEY` org secret. The glab/MR-comment plumbing does not port — the action comments natively on PRs.

## CI images (infrastructure-gitlab-ci/images/)

`jdk-gcp`, `report-generator`, `newman` currently build via dind into the GitLab registry. Disposition: `report-generator` is obsoleted by the coverage recipe; `newman` → `newman` CLI via `setup-node` (no image needed); `jdk-gcp` → replaced by `setup-java` (Temurin) + `setup-gcloud` on hosted runners. If an image is still genuinely needed, build it in Actions with `docker/build-push-action` → Artifact Registry (see ISSUE-1751 for the jdk-gcp→AR precedent) — no dind service, hosted runners have Docker natively.
