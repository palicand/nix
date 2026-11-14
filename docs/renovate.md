# Renovate

[Renovate runs in GitHub Actions][action] after every push to `main` (including
merges) and every hour at minute 17. It maintains
update PRs and a Dependency Dashboard issue using `config:recommended`.
Branches are rebased when behind the base branch; automerge is disabled.
Dashboard retry/rebase requests are picked up on the next run. Use workflow
**Run workflow** for an immediate run, optionally with **dry-run** enabled.
GitHub can delay scheduled runs.

## Setup

1. Add a repository Actions secret named `RENOVATE_TOKEN`. Use a dedicated bot
   account for bot attribution, or your own account for personal attribution.
   A classic PAT needs `repo` (or `public_repo` for this public repository) and
   `workflow` scopes. The latter allows Renovate to update Actions themselves.
   See the [action's token requirements][token]. Avoid `GITHUB_TOKEN`: updates
   made with it do not trigger the normal PR CI workflows.
2. Merge the configuration and run Renovate manually with **dry-run** first.
3. Run it normally and inspect the Dependency Dashboard and first update PRs.
   Close superseded PRs from the old updater workflows manually.

The [free hosted plan cannot run post-upgrade commands][free], which are needed
for platform checksums. `enabled: false` in `renovate.json` disables the hosted
bot for this repository. The Actions runner overrides it through its global
`force` configuration and uses a separate branch prefix. Keep this override in
`.github/renovate-config.cjs`.

## Updates

- The opt-in [Nix manager][nix] maintains the root and all three package flake
  locks weekly, before 09:00 Monday in Europe/Prague.
- Custom regex managers advance herdr and Homebrew release pins, then update
  their corresponding root lock entries. The Nix manager ignores these two
  inputs to avoid competing updates.
- Codex and Kotlin LSP versions come from GitHub releases, with their respective
  tag prefixes stripped. Claude Code follows its existing `latest` CDN channel.
- Package updates call the existing `pkgs/*/update.sh` with Renovate's selected
  version and commit the refreshed platform checksums. The global command
  allowlist accepts only the three scripts with numeric versions and the two
  named flake updates.
- GitHub Actions and the Renovate image version are also maintained by Renovate.

The runner uses the full Renovate image for Nix and supporting tools, with
[`RENOVATE_BINARY_SOURCE: install`][binary-source] in the workflow environment so
post-upgrade tasks can install declared tools such as `gh`. The full image sets
the environment default to `global`, overriding file configuration, which
[ignores `installTools`][install-tools] and leaves Codex checksum updates without
`gh`. It saves
repository and datasource caches between successful runs using fresh cache keys,
following the [action's caching guidance][cache]. Upstream versions still come
from their normal Renovate datasources; no private dependency database is needed.

CI retains the system closure comparison for root flake changes. Its rendered
package list appears in the **System package changes (mac-2026)** job summary,
instead of the update PR body. Release notes use Renovate's normal PR rendering;
availability depends on upstream metadata.

Local `update-all` and the package update scripts remain available.

[action]: https://github.com/renovatebot/github-action
[token]: https://github.com/renovatebot/github-action#token
[free]: https://docs.renovatebot.com/mend-hosted/faq/#community-free-users
[nix]: https://docs.renovatebot.com/modules/manager/nix/
[cache]: https://github.com/renovatebot/github-action#persisting-the-repository-cache
[binary-source]: https://docs.renovatebot.com/self-hosted-configuration/#binarysource
[install-tools]: https://docs.renovatebot.com/configuration-options/#postupgradetasksinstalltools
