# Declarative Agent Skills

Single source of truth for agent skills in `~/.nixpkgs`, linked into multiple
agent harnesses (Claude Code, Codex). Self-written skills live in this repo;
third-party skills are declared in Nix but installed by the [skills CLI][skills-cli]
(`npx skills`) — the same declarative-list / native-installer split as the
nix-darwin [homebrew module][homebrew-module].

## Inventory (2026-07-10)

**Self-written** (real dirs in `~/.claude/skills/`), migrating into this repo:

- `address-pr-review`, `announce-pr`, `bkbn-implement-tickets`, `bkbn-my-queue`,
  `commit`, `migrate-gitlab-ci`, `squash-merge`

**Deleted, not migrated**: `bkbn-ticket-audit`, `bkbn-ticket-family`,
`bkbn-ticket-show` — stale local copies of skills that now live in the
`bkbn-core` plugin (plugin versions are newer). The plugin stays their source.

**Third-party** (installed via `npx skills` into `~/.agents/skills/`):

| Source | Skills |
|---|---|
| `coreyhaines31/marketingskills` | copywriting, product-marketing |
| `vercel-labs/skills` | find-skills |
| `DietrichGebert/ponytail` | ponytail, ponytail-audit, ponytail-debt, ponytail-gain, ponytail-help, ponytail-review |

**Out of scope**: Claude Code plugins (superpowers, bkbn-core, pr-review-toolkit,
obsidian, LSPs, …) — managed by Claude Code's own plugin system, which actively
rewrites its state files; project-level skills; Claude Code built-in skills.

## Decisions

1. **Plugins excluded** — only standalone skills are codified.
2. **Brew model for third-party** — Nix declares the desired list; `npx skills`
   installs and owns `~/.agents/skills/` + `~/.agents/.skill-lock.json`. No
   flake inputs, no store-pinning. Versions float at HEAD-at-install-time,
   tracked by the CLI's lock file, exactly as Brewfile state works for
   Homebrew. Ad-hoc `npx skills add` keeps working (additive; `cleanup = none`
   semantics, mirroring the homebrew config).
3. **Own skills via out-of-store symlinks** — editable in place, no rebuild to
   iterate on prompts.
4. **Canonical dir topology** — everything is reachable at
   `~/.agents/skills/<name>` (the skills-CLI convention); per-agent dirs
   symlink into it. [Codex][codex-skills] reads global skills from
   `~/.codex/skills/` and project skills from `.agents/skills` dirs, so both
   paths are covered.
5. **Auto-upgrade off by default**, one boolean switch to enable brew-style
   upgrade-on-activation.

## Architecture

### Repo layout

```
~/.nixpkgs/
├── skills/                          # self-written skills, source of truth
│   ├── address-pr-review/SKILL.md
│   ├── announce-pr/…
│   ├── bkbn-implement-tickets/…
│   ├── bkbn-my-queue/…
│   ├── commit/…
│   ├── migrate-gitlab-ci/…
│   └── squash-merge/…
└── modules/home-manager/skills/default.nix
```

### Module: `modules/home-manager/skills/default.nix`

Imported from `modules/home-manager/default.nix`. No custom option plumbing —
plain `let` bindings at the top of the module hold the configuration:

```nix
let
  upgradeOnActivation = false;              # the one switch (brew-style when true)
  agentSkillDirs = {                        # agent name -> skills dir under $HOME
    claude-code = ".claude/skills";
    codex = ".codex/skills";
  };                                        # attr names double as `skills add -a` values
  externalSkills = [
    { source = "coreyhaines31/marketingskills";
      skills = [ "copywriting" "product-marketing" ]; }
    { source = "vercel-labs/skills";
      skills = [ "find-skills" ]; }
    { source = "DietrichGebert/ponytail";
      skills = [ "ponytail" "ponytail-audit" "ponytail-debt"
                 "ponytail-gain" "ponytail-help" "ponytail-review" ]; }
  ];
in …
```

**Self-written skills** — names auto-discovered with `builtins.readDir` on the
repo `skills/` dir (adding a skill = create the dir + `git add`; no module
edit). For each name, `home.file` entries using
[`mkOutOfStoreSymlink`][hm-manual]:

- `~/.agents/skills/<name>` → `~/.nixpkgs/skills/<name>` (canonical)
- `~/.claude/skills/<name>` → `~/.agents/skills/<name>`
- `~/.codex/skills/<name>` → `~/.agents/skills/<name>`

Per-skill links, never whole-directory: `~/.codex/skills/.system/` and any
unmanaged experiments must survive, and `~/.agents/skills/` stays writable for
the skills CLI.

**Third-party skills** — a `home.activation` step (DAG: after
`writeBoundary`), invoking the CLI as `${pkgs.nodejs}/bin/npx -y skills`:

1. Presence is a filesystem check: a skill is installed iff
   `~/.agents/skills/<name>` exists. No `npx` invocation on the happy path.
2. For each declared skill that is missing → one `skills add` per skill:
   `npx -y skills add <source> -g -s <skill> -a claude-code -a codex -y`,
   with node and git prepended to PATH (home-manager's activation PATH has
   neither; the CLI's bin resolves node via `/usr/bin/env` and shells out to
   `git clone`). Batched `-s a b` / `-a x y` forms misparse, and a single
   `-a` value flips the CLI into copy mode, which skips the canonical
   `~/.agents/skills/` dir entirely — both verified live during rollout.
3. For each declared skill present in `~/.agents/skills/` but missing its link
   in some agent dir, create the symlink directly, matching the CLI's
   convention (relative link, e.g. `~/.codex/skills/ponytail` →
   `../../.agents/skills/ponytail`). Never re-run `skills add` for a mere
   missing link — re-adding reinstalls at HEAD, i.e. a surprise upgrade.
4. If `upgradeOnActivation` → `npx -y skills update -g -y`.
5. Network failures warn and skip; activation never fails the switch. When
   everything is present and upgrade is off, the step runs no `npx` at all.

### Invariants

- Nix never writes into `~/.agents/skills/` for third-party skills; the CLI
  owns that state (lock file stays authoritative, `skills update` keeps
  working).
- Third-party skills are never silently upgraded unless
  `upgradeOnActivation = true` or the user runs `npx skills update`.
- Undeclared skills are left alone (additive, like `homebrew.onActivation.cleanup
  = "none"`). Codifying an ad-hoc install = add it to `externalSkills`.

## Migration (one-time, during implementation)

1. Move the 7 self-written skill dirs from `~/.claude/skills/` into
   `~/.nixpkgs/skills/`; `git add`.
2. Delete from `~/.claude/skills/`: the 3 stale bkbn dupes and the 7 moved
   originals (home-manager fails on clobber otherwise). Leave the 9 npx
   symlinks — they already point at `~/.agents/skills/` and stay valid; the
   module only adds the missing codex links.
3. Wire the module into `modules/home-manager/default.nix` imports; `git add`.
4. `sudo darwin-rebuild switch --flake ~/.nixpkgs`.

## Verification

- `ls -la ~/.agents/skills ~/.claude/skills ~/.codex/skills` — every declared
  skill resolves; `.system/` intact in codex.
- `npx -y skills ls -g` still lists the 9 third-party skills.
- Fresh `claude` session lists all 16 skills (7 own + 9 external) without
  duplicates; fresh `codex` session surfaces them via `/skills`.
- Second `darwin-rebuild switch` is a no-op (idempotent, no network).
- Flip test: temporarily delete `~/.codex/skills/ponytail` link, re-switch,
  link is restored without the skill being reinstalled.

[skills-cli]: https://github.com/vercel-labs/skills
[codex-skills]: https://developers.openai.com/codex/skills
[homebrew-module]: https://nix-darwin.github.io/nix-darwin/manual/index.html
[hm-manual]: https://nix-community.github.io/home-manager/
