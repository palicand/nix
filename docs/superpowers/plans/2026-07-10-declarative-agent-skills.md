# Declarative Agent Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `~/.nixpkgs` the single source of truth for agent skills — self-written skills live in the repo, third-party skills are declared in Nix and installed by `npx skills`, all linked into Claude Code and Codex.

**Architecture:** A new `skills/` dir at repo root holds self-written skills; a new home-manager module auto-discovers them and links them (out-of-store symlinks) through the canonical `~/.agents/skills/` dir into `~/.claude/skills/` and `~/.codex/skills/`. Third-party skills follow the nix-darwin homebrew pattern: a declarative list in the module, installed at activation by `npx skills` only when missing.

**Tech Stack:** Nix flakes, nix-darwin, home-manager (`home.file`, `mkOutOfStoreSymlink`, `home.activation` DAG), the `skills` CLI (`npx skills`).

Spec: `docs/superpowers/specs/2026-07-10-declarative-skills-design.md`

## Global Constraints

- `upgradeOnActivation = false` by default — the only auto-update switch. Third-party skills must never be reinstalled/upgraded unless this is `true`, the skill is absent, or the user runs `npx skills update` themselves.
- Additive semantics: never remove or touch skills that are installed but not declared.
- Nix never writes into `~/.agents/skills/` for third-party skills; the `skills` CLI owns that state (`~/.agents/.skill-lock.json` stays authoritative).
- Per-skill symlinks only, never whole-directory links (`~/.codex/skills/.system/` and ad-hoc experiments must survive).
- New files must be `git add`ed before any `darwin-rebuild` (flakes only see tracked files).
- Run `nixfmt` on new/changed `.nix` files before committing.
- Commit messages: title line only, plus `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.
- Activation must never fail the switch on network errors — warn and continue.
- `darwin-rebuild build` needs no sudo; `darwin-rebuild switch` needs sudo (passwordless here).

---

### Task 1: Move self-written skills into the repo

**Files:**
- Create: `skills/address-pr-review/`, `skills/announce-pr/`, `skills/bkbn-implement-tickets/`, `skills/bkbn-my-queue/`, `skills/commit/`, `skills/migrate-gitlab-ci/`, `skills/squash-merge/` (copied wholesale from `~/.claude/skills/`)

**Interfaces:**
- Produces: `~/.nixpkgs/skills/<name>/SKILL.md` for the 7 names above — Task 2's module auto-discovers exactly these directory names via `builtins.readDir`.

**Note:** Copy, don't move — the originals in `~/.claude/skills/` stay live until the switch in Task 3, so agents keep working mid-migration. Do NOT copy `bkbn-ticket-audit`, `bkbn-ticket-family`, `bkbn-ticket-show` (stale dupes of `bkbn-core` plugin skills; they get deleted in Task 3).

- [ ] **Step 1: Copy the 7 skill dirs into the repo**

```bash
mkdir -p ~/.nixpkgs/skills
for s in address-pr-review announce-pr bkbn-implement-tickets bkbn-my-queue commit migrate-gitlab-ci squash-merge; do
  cp -R ~/.claude/skills/$s ~/.nixpkgs/skills/$s
done
```

- [ ] **Step 2: Verify every copy has a SKILL.md and nothing extra came along**

Run: `ls ~/.nixpkgs/skills/ && for s in ~/.nixpkgs/skills/*/; do [ -f "$s/SKILL.md" ] && echo "OK $s" || echo "MISSING SKILL.md: $s"; done`
Expected: exactly the 7 dirs, `OK` for each, no `MISSING` lines.

- [ ] **Step 3: Commit**

```bash
cd ~/.nixpkgs && git add skills/ && git commit -m "feat(skills): Move self-written agent skills into the repo

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Skills home-manager module

**Files:**
- Create: `modules/home-manager/skills/default.nix`
- Modify: `modules/home-manager/default.nix:10-15` (imports list)

**Interfaces:**
- Consumes: `~/.nixpkgs/skills/<name>/` dirs from Task 1 (via `builtins.readDir ../../../skills`).
- Produces: `home.file` entries `".agents/skills/<name>"`, `".claude/skills/<name>"`, `".codex/skills/<name>"` for each local skill; `home.activation.externalAgentSkills` DAG entry. Task 3 relies on activation creating missing agent links as relative symlinks `../../.agents/skills/<name>`.

- [ ] **Step 1: Create `modules/home-manager/skills/default.nix`**

```nix
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # The one switch: true = brew-style "pull latest on every darwin-rebuild switch"
  upgradeOnActivation = false;

  # Agent name (must be a valid `skills add -a` value) -> skills dir under $HOME.
  # Both dirs are two levels below $HOME; the relative links below assume that.
  agentSkillDirs = {
    claude-code = ".claude/skills";
    codex = ".codex/skills";
  };

  # Third-party skills, installed and owned by `npx skills` (brew model:
  # declared here, installed by the native tool, additive like cleanup=none).
  externalSkills = [
    {
      source = "coreyhaines31/marketingskills";
      skills = [
        "copywriting"
        "product-marketing"
      ];
    }
    {
      source = "vercel-labs/skills";
      skills = [ "find-skills" ];
    }
    {
      source = "DietrichGebert/ponytail";
      skills = [
        "ponytail"
        "ponytail-audit"
        "ponytail-debt"
        "ponytail-gain"
        "ponytail-help"
        "ponytail-review"
      ];
    }
  ];

  homeDir = config.home.homeDirectory;
  outOfStore = config.lib.file.mkOutOfStoreSymlink;

  # Self-written skills: every directory under <repo>/skills, no registration needed.
  localSkills = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../../skills)
  );

  # <name> -> ~/.agents/skills/<name> -> ~/.nixpkgs/skills/<name> (live-editable),
  # plus per-agent links into the canonical dir.
  localSkillLinks = lib.listToAttrs (
    lib.concatMap (
      name:
      [
        {
          name = ".agents/skills/${name}";
          value.source = outOfStore "${homeDir}/.nixpkgs/skills/${name}";
        }
      ]
      ++ map (dir: {
        name = "${dir}/${name}";
        value.source = outOfStore "${homeDir}/.agents/skills/${name}";
      }) (lib.attrValues agentSkillDirs)
    ) localSkills
  );

  npx = "${pkgs.nodejs}/bin/npx";
  agentNames = lib.concatStringsSep " " (lib.attrNames agentSkillDirs);

  # Install a source's skills only when absent from ~/.agents/skills —
  # presence is a filesystem check, so the happy path never invokes npx.
  installSnippet =
    { source, skills }:
    ''
      missing=""
      for skill in ${lib.concatStringsSep " " skills}; do
        [ -e "$HOME/.agents/skills/$skill" ] || missing="$missing $skill"
      done
      if [ -n "$missing" ]; then
        run ${npx} -y skills add ${source} -g -s $missing -a ${agentNames} -y \
          || echo "warning: skills add$missing from ${source} failed (offline?)"
      fi
    '';

  # Re-create a missing agent link without reinstalling (a `skills add` re-run
  # would pull HEAD, i.e. a surprise upgrade). Same relative-link convention
  # as the CLI; both agent dirs sit two levels below $HOME.
  relinkSnippet =
    { skills, ... }:
    lib.concatMapStrings (
      skill:
      lib.concatMapStrings (dir: ''
        if [ -e "$HOME/.agents/skills/${skill}" ] \
          && [ ! -e "$HOME/${dir}/${skill}" ] && [ ! -L "$HOME/${dir}/${skill}" ]; then
          run mkdir -p "$HOME/${dir}"
          run ln -s "../../.agents/skills/${skill}" "$HOME/${dir}/${skill}"
        fi
      '') (lib.attrValues agentSkillDirs)
    ) skills;
in
{
  home.file = localSkillLinks;

  home.activation.externalAgentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    ''
      run mkdir -p "$HOME/.agents/skills"
    ''
    + lib.concatMapStrings installSnippet externalSkills
    + lib.concatMapStrings relinkSnippet externalSkills
    + lib.optionalString upgradeOnActivation ''
      run ${npx} -y skills update -g -y || echo "warning: skills update failed (offline?)"
    ''
  );
}
```

- [ ] **Step 2: Wire the import in `modules/home-manager/default.nix`**

Change the imports list (currently lines 10–15) to:

```nix
  imports = [
    ./zsh
    ./git
    ./fish
    ./skills
    ./pre-commit.nix
  ];
```

- [ ] **Step 3: Format and stage (flake must see the new file)**

```bash
cd ~/.nixpkgs && nixfmt modules/home-manager/skills/default.nix \
  && git add modules/home-manager/skills/default.nix modules/home-manager/default.nix
```

- [ ] **Step 4: Eval test — module produces exactly 21 link entries (7 skills x 3 dirs)**

Run:
```bash
cd ~/.nixpkgs && nix eval ".#darwinConfigurations.$(scutil --get LocalHostName).config.home-manager.users.palicand.home.file" \
  --apply 'files: builtins.length (builtins.filter (n: (builtins.match "(\\.agents|\\.claude|\\.codex)/skills/.*" n) != null) (builtins.attrNames files))'
```
Expected: `21`

- [ ] **Step 5: Build test (no sudo, no activation)**

Run: `darwin-rebuild build --flake ~/.nixpkgs`
Expected: exits 0. If it fails with "path does not exist", a file wasn't `git add`ed.

- [ ] **Step 6: Commit**

```bash
cd ~/.nixpkgs && git commit -m "feat(skills): Declarative agent skills module for Claude Code and Codex

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" -- modules/home-manager/skills/default.nix modules/home-manager/default.nix
```

---

### Task 3: Migrate live state and switch

**Files:**
- None in the repo — this task mutates `~/.claude/skills/` and runs the switch.

**Interfaces:**
- Consumes: Task 1's repo copies, Task 2's module. home-manager refuses to clobber existing real dirs, so the originals MUST be deleted before the switch; if the switch fails with "would be clobbered", a dir was missed.

- [ ] **Step 1: Safety check — repo copies exist before deleting originals**

Run: `for s in address-pr-review announce-pr bkbn-implement-tickets bkbn-my-queue commit migrate-gitlab-ci squash-merge; do [ -f ~/.nixpkgs/skills/$s/SKILL.md ] || echo "ABORT: $s missing from repo"; done; echo done`
Expected: only `done`. Any `ABORT` line → stop, fix Task 1.

- [ ] **Step 2: Delete the 7 moved originals and the 3 stale bkbn dupes**

```bash
for s in address-pr-review announce-pr bkbn-implement-tickets bkbn-my-queue commit migrate-gitlab-ci squash-merge \
         bkbn-ticket-audit bkbn-ticket-family bkbn-ticket-show; do
  rm -rf ~/.claude/skills/$s
done
```

- [ ] **Step 3: Switch**

Run: `sudo darwin-rebuild switch --flake ~/.nixpkgs`
Expected: exits 0. Activation output contains no `npx` invocations (all 9 external skills already present) except the relink lines creating missing codex links.

- [ ] **Step 4: Verify link topology**

Run:
```bash
readlink ~/.agents/skills/commit | grep -o 'home-files/.agents/skills/commit\|/nix/store/.*' | head -1; \
readlink -f ~/.claude/skills/commit; \
readlink -f ~/.codex/skills/commit; \
readlink ~/.codex/skills/ponytail; \
ls ~/.codex/skills/.system/ | head -3; \
ls ~/.claude/skills/ | wc -l
```
Expected:
- `readlink -f ~/.claude/skills/commit` and `readlink -f ~/.codex/skills/commit` both resolve to `/Users/palicand/.nixpkgs/skills/commit`
- `readlink ~/.codex/skills/ponytail` → `../../.agents/skills/ponytail`
- `.system/` listing intact (imagegen, openai-docs, …)
- `~/.claude/skills/` has 16 entries (7 own + 9 external)

- [ ] **Step 5: Verify the skills CLI still owns third-party state**

Run: `cd ~ && npx -y skills ls -g 2>&1 | grep -c 'copywriting\|product-marketing\|find-skills\|ponytail'`
Expected: count ≥ 9 (all nine external skills listed; lock file untouched by the switch).

- [ ] **Step 6: Idempotency — second switch is a no-op**

Run: `sudo darwin-rebuild switch --flake ~/.nixpkgs`
Expected: exits 0, no `npx` calls, no `ln` output in activation.

- [ ] **Step 7: Flip test — deleted agent link is restored WITHOUT reinstall**

```bash
rm ~/.codex/skills/ponytail
sudo darwin-rebuild switch --flake ~/.nixpkgs
readlink ~/.codex/skills/ponytail
```
Expected: link restored to `../../.agents/skills/ponytail`; activation output shows `ln -s`, NOT `skills add`.

- [ ] **Step 8: Reinstall test — a fully deleted skill is reinstalled via npx**

```bash
rm -rf ~/.agents/skills/ponytail-help ~/.claude/skills/ponytail-help ~/.codex/skills/ponytail-help
sudo darwin-rebuild switch --flake ~/.nixpkgs
ls ~/.agents/skills/ponytail-help/SKILL.md && readlink ~/.claude/skills/ponytail-help
```
Expected: activation runs `npx … skills add DietrichGebert/ponytail -g -s ponytail-help …`; SKILL.md exists again; agent links restored. (This pulls HEAD of the ponytail repo — acceptable, it's the add path working as designed.) If the multi-value `-s`/`-a` flags misparse here, fall back to one `skills add` per missing skill in `installSnippet` and re-run from Task 2 Step 3.

- [ ] **Step 9: Fresh-session smoke test**

Run: `cd /tmp && claude -p "/skills" --max-turns 1 2>/dev/null | head -40` (or eyeball a fresh interactive `claude` session's skill list)
Expected: all 7 own skills and 9 external skills present, no duplicate `bkbn-ticket-*` entries (only the `bkbn-core:` plugin versions remain).

---

### Task 4: Document in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (repo root) — add an "Agent Skills" section after "Homebrew Management".

**Interfaces:**
- Consumes: final behavior from Tasks 1–3.

- [ ] **Step 1: Add the section**

```markdown
## Agent Skills

Single source of truth for agent skills (Claude Code + Codex), spec in
`docs/superpowers/specs/2026-07-10-declarative-skills-design.md`.

- **Self-written skills** live in `skills/<name>/SKILL.md` at the repo root.
  Auto-discovered by `modules/home-manager/skills/default.nix` — adding one is
  `mkdir skills/<name>` + write `SKILL.md` + `git add` + rebuild. Linked via
  out-of-store symlinks (`~/.agents/skills/<name>` → repo), so edits are live
  without a rebuild.
- **Third-party skills** are declared in `externalSkills` in the same module
  and installed by `npx skills` during activation, only when missing (brew
  model: Nix declares, the native CLI installs and owns
  `~/.agents/.skill-lock.json`). Updates: `npx skills update -g`, or flip
  `upgradeOnActivation = true` in the module for brew-style
  update-on-every-switch.
- Semantics are additive (like `homebrew.onActivation.cleanup = "none"`):
  ad-hoc `npx skills add` keeps working; codify keepers in `externalSkills`.
- The `bkbn-ticket-audit/family/show` skills come from the `bkbn-core` plugin,
  NOT this repo (local copies were retired as stale duplicates).
```

- [ ] **Step 2: Commit**

```bash
cd ~/.nixpkgs && git add CLAUDE.md && git commit -m "docs: Document declarative agent skills setup

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" -- CLAUDE.md
```

---

## Self-Review Notes

- Spec coverage: inventory migration (Task 1), module + auto-discovery + out-of-store links + activation install/relink/upgrade switch (Task 2), migration + all five spec verification bullets (Task 3 steps 3–9), docs (Task 4). Cleanup semantics need no code — additive is the absence of removal logic.
- The spec's "no network calls when everything present" is verified by Task 3 step 6.
- Type consistency: `agentSkillDirs` attr names are the `skills add -a` values; `relinkSnippet` ignores `source` via `{ skills, ... }`.
