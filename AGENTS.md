# Repository agent guide

This repository is a personal Nix configuration for macOS. It combines Nix
flakes, nix-darwin, Home Manager, nix-homebrew, and sops-nix. Prefer reading
the current configuration over relying on package or version inventories in
documentation.

## Repository layout

- `flake.nix` defines inputs, checks, development tooling, and Darwin hosts.
- `hosts/` contains host-specific configuration.
- `profiles/` composes configuration for a user or machine.
- `modules/common.nix` contains configuration shared by system profiles.
- `modules/darwin/` owns macOS system behavior: launchd, system defaults,
  Homebrew, fonts, secrets, and system services.
- `modules/home-manager/` owns user behavior: packages, shells, dotfiles,
  program settings, and agent skills.
- `pkgs/` contains locally packaged software; `tests/` contains repository
  checks.

Keep macOS system features in nix-darwin modules and portable user settings in
Home Manager. Put machine-specific choices in `hosts/`, not shared modules.
`modules/primary.nix` provides the `user.*` and `hm.*` aliases used throughout
the configuration.

## Working and validation

Use the smallest check that covers the change, then broaden it when warranted:

```bash
# Format or check edited Nix files
nixfmt <file.nix>
nixfmt --check <file.nix>

# Static analysis
statix check .

# Evaluate and build all flake checks
nix flake check

# Build one host without activating it
darwin-rebuild build --flake .#mac-2026
```

`darwin-rebuild switch` changes the live machine and requires `sudo`; run it
only when the user explicitly asks for activation. Likewise, do not update
flake inputs unless the task calls for dependency changes.

Nix flakes do not include untracked files. Stage a newly referenced module or
test before running flake evaluation. Do not commit merely to make evaluation
work.

The development shell provides repository-only tools such as `sops`,
`ssh-to-age`, and `nil`; direnv normally loads it automatically.

## Common changes

### Packages and applications

- Add essential system-wide CLI tools to `environment.systemPackages` in
  `modules/common.nix` or the relevant Darwin module.
- Add user packages to `home.packages` in
  `modules/home-manager/default.nix`.
- Add Homebrew formulae and casks in `modules/darwin/apps.nix`. Homebrew's
  installation is managed by nix-homebrew; package declarations are managed
  by nix-darwin.
- When changing the Home Manager Python environment, keep the package lists in
  the main `python.withPackages` expression and both Python wrapper scripts in
  sync. Do not hard-code the current Python minor version in documentation.

### Shells

- Put aliases and PATH entries shared by Fish and Zsh in
  `modules/home-manager/shared.nix`.
- Put shell-specific initialization in the corresponding `fish/` or `zsh/`
  module. Starship is configured in the Zsh module but integrates with both
  shells.
- Do not run `fish_update_completions`. Home Manager deliberately supplies
  completion paths, and regenerated caches can shadow working completions.
- GUI applications inherit environment variables from launchd, not an
  interactive shell. Configure GUI-visible variables in
  `modules/darwin/default.nix` when needed.

### macOS services

Define user agents under `launchd.user.agents` in a Darwin module. Keep each
service's executable, lifecycle policy, environment, and log paths together.
For substantial services, prefer a dedicated module and add focused checks
under `tests/`.

### Secrets

- Never commit plaintext secrets or interpolate secret values into Nix store
  derivations.
- Encrypted values live in `secrets/*.yaml`; recipient policy lives in
  `.sops.yaml`; declarations and rendered templates live in
  `modules/darwin/sops.nix`.
- Use sops-nix templates for configuration fragments that contain secret
  values. Refer to the rendered path from Nix configuration.
- When adding a secret, update both the encrypted file and its declaration.
  When adding or removing a machine, update recipients and re-encrypt existing
  secret files.

## Repository invariants and traps

- Do not change `system.stateVersion` or `home.stateVersion` as part of routine
  upgrades. They describe compatibility baselines, not installed versions.
- Nix definitions of shell-based Git aliases must remain single-line strings.
  Escape embedded quotes and separate commands with semicolons; literal
  newlines produce invalid Git configuration.
- Avoid defining the same Home Manager option in multiple shell modules.
  Configure shared programs once and enable per-shell integration where
  supported.
- The default shell must be enabled by nix-darwin and use its
  `/run/current-system/sw/bin/<shell>` path when selected with `chsh`.
- Preserve the sops-nix rendered-template pattern for Nix access tokens. Direct
  use of `nix.settings.access-tokens` would expose token contents through a
  world-readable store path.

## Agent skills

`modules/home-manager/skills/default.nix` is the declarative entry point for
agent skills:

- Self-written skills live in `skills/<name>/SKILL.md`. They are discovered
  automatically and linked out of store, so edits are live without rebuilding.
- Third-party skills belong in `externalSkills` and are installed by
  `npx skills` when absent. Keep `upgradeOnActivation = false` unless the user
  explicitly wants upgrades on every activation.
- Ad-hoc third-party installs remain allowed; declare only skills that should
  persist across machines.
- Do not recreate `bkbn-ticket-audit`, `bkbn-ticket-family`, or
  `bkbn-ticket-show` locally; the `bkbn-core` plugin owns them.

The design background is in
`docs/superpowers/specs/2026-07-10-declarative-skills-design.md`.
