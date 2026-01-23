# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal Nix configuration repository for managing macOS (nix-darwin) and home-manager configurations. It uses Nix flakes to define declarative system configurations, user environments, and package installations.

## Core Commands

### Building and Applying Configuration

```bash
# Rebuild and switch macOS configuration (primary command)
# NOTE: Requires sudo for system activation
sudo darwin-rebuild switch --flake ~/.nixpkgs

# Or use the shell alias (already includes sudo)
rebuild

# Build without switching (for testing - does NOT require sudo)
darwin-rebuild build --flake ~/.nixpkgs

# Check what would change without applying
darwin-rebuild build --flake ~/.nixpkgs
nix store diff-closures /run/current-system ./result

# Update all flakes and rebuild (combines flake update + rebuild)
update-all

# Preview what would change when updating (without building)
# Shows packages to build/download with sizes, updates flake.lock only
check-updates
```

**About `check-updates`**: Runs `nix flake update` then `nix build --dry-run` to show what packages would be built from source or downloaded (with sizes), without actually building anything. Use before `update-all` to see scope of changes and estimate download size.

### Flake Management

```bash
# Update all flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Show flake metadata
nix flake show

# Check flake for issues
nix flake check
```

### Package Management

```bash
# Search for packages in nixpkgs
nix search nixpkgs <package-name>

# Install package temporarily (one-off)
nix shell nixpkgs#<package-name>

# Run package without installing
nix run nixpkgs#<package-name>

# Temporary shell with multiple packages (custom command)
nix-temp jq ripgrep fd
# Automatically prepends nixpkgs# to package names
# Supports explicit flake references: nix-temp jq github:owner/repo#pkg
```

### Garbage Collection

```bash
# Clean up old generations (automatic GC configured for 14 days)
nix-collect-garbage -d

# List generations
nix-env --list-generations
darwin-rebuild --list-generations
```

## Architecture

### Flake Structure

The `flake.nix` is the entry point that orchestrates the entire configuration:

- **Inputs**: Defines dependencies (nixpkgs unstable, home-manager, nix-darwin, pre-commit-hooks)
- **Outputs**: Generates darwin configurations using helper functions `mkDarwinConfig` and `mkHomeConfig`
- **Darwin Configuration**: `uber-mac` for aarch64-darwin (Apple Silicon)
- **Development Shell**: Provides `nix develop` with pre-commit hooks for automatic Nix formatting
- **Simplified**: Removed unused flake inputs (stable nixpkgs, comma, devshell, flake-compat, flake-utils) for faster rebuilds

### Module System

Layered module architecture:

1. **modules/primary.nix**: Defines `user` and `hm` option aliases for shorthand config
2. **modules/common.nix**: Shared configuration (essential utilities, shell config, home-manager bootstrap)
3. **modules/darwin/default.nix**: Darwin base (system settings, zsh, nixpkgs.config)
4. **modules/darwin/apps.nix**: Homebrew casks and brews
5. **modules/home-manager/default.nix**: User environment (packages, python, tmux, app linking)
6. **Specialized modules**: shared.nix (shell aliases/PATH), zsh/default.nix, fish/default.nix, git/default.nix (worktree workflow), charging-chime.nix

### Profile System

Profiles compose modules for specific use cases:

- **profiles/personal.nix**: Sets `user.name = "palicand"` and imports home-manager/personal.nix
- Applied to the `uber-mac` configuration in flake.nix

### Key Patterns

- **User Aliasing**: The `primary.nix` module allows `user.*` and `hm.*` as shortcuts to `users.users.<username>.*` and `home-manager.users.<username>.*`
- **Input Following**: Both home-manager and nix-darwin follow the same nixpkgs input for consistency
- **Single nixpkgs**: Uses nixpkgs unstable channel exclusively for all packages
- **Platform Abstraction**: `homePrefix` function handles /Users (macOS) vs /home (Linux) paths
- **Module Boundaries**: Put things in the right place:
  - **nix-darwin** (`modules/darwin/`): macOS system features - launchd agents, system defaults, Homebrew, fonts, system packages
  - **home-manager** (`modules/home-manager/`): User environment - shell config, dotfiles, user packages, program settings
  - Rule of thumb: If it's a macOS-specific system feature (like launchd), use darwin. If it's user/shell configuration that could work on any system, use home-manager.

## Common Modifications

### Adding System Packages

Add to `modules/common.nix` under `environment.systemPackages` for essential system utilities only, or to `modules/home-manager/default.nix` under `home.packages` for user-specific packages.

### Adding Python Packages

Edit `modules/home-manager/default.nix`:
1. Find the `python3.withPackages` expression (around line 107)
2. Add package name to the list within the `with ps;` block
3. **Important**: Also add it to the wrapper scripts (lines 114-119) to keep them in sync
4. Run `darwin-rebuild switch --flake ~/.nixpkgs`

**Why wrapper scripts**: The `python3` symlink doesn't properly initialize `sys.path`. Wrapper scripts execute `python3.13` directly (which works correctly), made transparent via shell aliases.

### Adding Homebrew Apps

Modify `modules/darwin/apps.nix`:
- GUI apps: add to `homebrew.casks`
- CLI tools: add to `homebrew.brews`

### Modifying Shell Configuration

**Shared configuration** (applies to both Fish and Zsh):
- Edit `modules/home-manager/shared.nix` for aliases and PATH that should work in both shells
- `aliases` - Attribute set of shell aliases (e.g., `grep = "rg"`)
- `sessionPath` - List of directories to add to PATH

**Shell-specific configuration**:
- **Zsh**: `modules/home-manager/zsh/default.nix` - environment variables in `programs.zsh.localVariables`, initialization in `programs.zsh.initContent`
- **Fish**: `modules/home-manager/fish/default.nix` - environment variables and initialization in `programs.fish.shellInit` or `interactiveShellInit`
- **Starship Prompt**: Edit `programs.starship.settings` in `modules/home-manager/zsh/default.nix` (works for both Fish and Zsh)

**Adding shell-specific PATH entries**:
```nix
# In zsh/default.nix - extends shared paths
home.sessionPath = shared.sessionPath ++ [
  "$HOME/.antigravity/antigravity/bin"
];
```

### Scheduling Tasks with launchd

Use `launchd.user.agents` in `modules/darwin/default.nix` to schedule periodic tasks on macOS.

**Key serviceConfig options** (see `man launchd.plist`):
- `StartInterval` - Run every N seconds (e.g., 86400 for daily)
- `StartCalendarInterval` - Cron-like scheduling with Weekday (0-6), Month (1-12), Day (1-31), Hour (0-23), Minute (0-59)
- `StandardOutPath` / `StandardErrorPath` - Log file paths
- `KeepAlive` - Restart if process exits
- `RunAtLoad` - Run immediately when loaded

**Managing agents**: Use `launchctl list | grep org.nixos`, `launchctl start org.nixos.<name>`, or `launchctl print gui/$(id -u)/org.nixos.<name>` to manage agents.

### Customizing Starship Prompt

Configured in `modules/home-manager/zsh/default.nix` under `programs.starship.settings` (works for both Fish and Zsh).

**Current**: Two-line format with directory, git, kubernetes. GCloud disabled, directory always visible.

**To customize**: Edit `programs.starship.settings` in `modules/home-manager/zsh/default.nix`, then rebuild.

**Resources**: [Starship docs](https://starship.rs/config/), [Presets](https://starship.rs/presets/)

### Changing User Settings

The primary user is "palicand" defined in:
- `modules/darwin/default.nix` (`system.primaryUser`)
- `profiles/personal.nix` (`user.name`)

### Configuring Charging Chime

Toggle macOS charging alert sound in `modules/darwin/default.nix`:
```nix
system.chargingChime.enable = false;  # Disable (current setting)
system.chargingChime.enable = true;   # Enable
```

Activation script runs automatically during `darwin-rebuild switch`.

## Important Configuration Details

- **State Version**: home-manager uses "25.11", darwin uses state version 6
- **Garbage Collection**: Automatic, runs daily at 1:30 PM, deletes generations older than 14 days
- **Experimental Features**: nix-command and flakes enabled
- **Default Shell**: Fish (configured in `modules/common.nix`)
- **Alternative Shells**: Zsh is still configured and available
- **Python Environment**: Python 3 with ipython, asyncpg, and requests (managed via `python3.withPackages`)
- **Shell Aliases**: Common aliases defined in `modules/home-manager/shared.nix` include `rebuild`, `update-all`, `check-updates`, `grep→rg`, `cat→bat`, `ls/ll` with colors, `k→kubectl`, and `nix-temp` function for temporary package shells
- **Command Aliases Note**: `check-updates` requires GNU AWK (gawk); `awk` is aliased to `gawk` for this purpose
- **Command-not-found**: When typing an unknown command, suggests which Nix package provides it
  - Uses pre-built database from `nix-index-database` flake (no manual `nix-index` needed)
  - Database updates automatically when flake inputs are updated via `nix flake update`
  - Integrated via `home-manager.sharedModules` in `flake.nix`
- **Fish Shell Configuration**:
  - Welcome message disabled via `set -g fish_greeting` in `modules/home-manager/fish/default.nix`
  - Tab completion paths fixed via `conf.d/zzz_completion_paths.fish` - adds Fish built-ins (1000+ commands) and Homebrew paths that home-manager doesn't include by default
  - **Atuin**: Smart shell history with frequency-based, context-aware search
    - Replaces Ctrl+R with fuzzy search interface
    - Learns from your command usage patterns to prioritize frequently-used commands
    - Configured in `modules/home-manager/fish/default.nix` with `programs.atuin`
    - Settings: fuzzy search mode, global filter, compact style, no cloud sync (privacy)
    - Makes command history truly predictive based on your actual usage
  - **plugin-git**: Automatically creates `g*` abbreviations for all git aliases (like oh-my-zsh git plugin does for Zsh)
- **Starship Prompt**: Configured in `modules/home-manager/zsh/default.nix`, works for both Fish and Zsh. See "Customizing Starship Prompt" section for details.
- **GUI App Environment**: `launchd.user.envVariables.PATH` configured to include Homebrew and Nix paths so GUI apps (like Lens) can find command-line tools
- **Homebrew on Activation**: Both `onActivation.autoUpdate = true` and `onActivation.upgrade = true` in `modules/darwin/apps.nix` - automatically updates package lists and upgrades all Homebrew packages when running `darwin-rebuild switch`
- **PATH Configuration**: `home.sessionPath` includes `/opt/homebrew/share/google-cloud-sdk/bin` for Google Cloud SDK components like `gke-gcloud-auth-plugin`

## Git Worktree Workflow

This configuration includes an enhanced git worktree workflow for parallel development with two commands:

### `git wt` / `gwt` - Simple Worktree

Direct alias to `git worktree` for standard worktree operations:

```bash
git wt list                    # List all worktrees
git wt add <path> <branch>     # Create a new worktree
git wt remove <path>           # Remove a worktree
gwt list                       # Shorthand (automatically created by oh-my-zsh/plugin-git)
```

### `git cwt` / `gcwt` - Worktree with Config Copy

Creates a new worktree with automatic secret/config file copying and auto-cd:

```bash
git cwt <dir-suffix> <branch-name>   # Create worktree with config copy
gcwt <dir-suffix> <branch-name>      # Same + automatically cd into it
```

**Features:**
- Creates worktree in parent directory as `<repo-name>-<dir-suffix>`
- Automatically copies relevant git-ignored config files to the new worktree
- Uses `rsync` with `--info=progress2` to show overall progress (percentage, speed, ETA) when copying files
- Shows file count before copying and completion message after
- Uses `origin/main` or `origin/master` as the base branch
- Example: `git cwt feature-123 feat/my-feature` creates `backend-platform-feature-123`

**Configurable File Extensions:**

The file extensions to copy are configurable via git config. Default extensions:
```
env|vscode|idea|gradle|properties|yaml|yml|json
```

**Customize per repository:**
```bash
git config worktree.copyExtensions "env|properties|json|xml"
```

**Customize globally for all repos:**
```bash
git config --global worktree.copyExtensions "env|properties|json"
```

**Usage Example:**
```bash
gcwt extension-error BKBN-3828-my-feature
# Creates worktree, copies configs, and immediately cd's into it
```

**Use cases**: Testing features in isolation with separate environment configs, working on multiple branches simultaneously, quick context switching without stashing changes.

**Implementation**: Git aliases defined in `modules/home-manager/git/default.nix`; `gcwt` shell function in both zsh and fish configs. The oh-my-zsh git plugin (Zsh) and plugin-git (Fish) automatically create `gwt` and `gcwt` abbreviations. Note: Git aliases in Nix must be single-line strings (use semicolons, not newlines).

## Notable Packages

- **Development**: rustup, nodejs, yarn, jdk21, poetry, cmake
- **Python Tools**: uv (fast package installer), ipython, asyncpg, requests
- **Cloud/DevOps**: kubernetes-helm, k9s, terraform, stripe-cli, glab (GitLab CLI), auth0-cli
- **Cloud SDK** (Homebrew): gcloud-cli (with GKE auth plugin, gsutil, bq) - uses Homebrew instead of Nix to avoid Python cryptography issues
- **Database**: postgresql_14, pgcli
- **CLI Tools**: ripgrep, bat, fzf, jq, yq, gawk (GNU AWK for check-updates), htop, tree, tig, ffmpeg, jwt-cli, cloc
- **Terminal**: tmux (with cpu, resurrect, sensible, yank plugins)
- **Nix Tools**: nixfmt (official formatter), nixfmt-tree (treefmt wrapper for directory formatting)
- **Fish Plugins**: z (directory jumper), fzf-fish, done (notifications), autopair (bracket pairing), plugin-git (auto g* abbreviations), based (base conversion)
- **AI**: claude-code
- **GUI Apps** (Homebrew): JetBrains Toolbox, Lens, Postman, gcloud-cli, VLC, Firefox, Tor Browser, Spotify, Signal, Slack, WhatsApp, Stats, Alfred, KeePassXC, iTerm2, iter.ai, CrossOver, Mullvad VPN, 1Password, GitHub Desktop, QBittorrent, Iosevka Nerd Font

## Homebrew Management

**Two-part approach**:
- **nix-homebrew**: Manages Homebrew installation (configured in `flake.nix`). No custom taps currently - `bundle` and `services` commands are built into modern Homebrew.
- **nix-darwin homebrew module**: Manages packages (brews, casks, Mac App Store apps) in `modules/darwin/apps.nix`. Auto-updates packages on `darwin-rebuild switch`.

**Adding a new tap**: Add as flake input in `flake.nix` (set `flake = false`), add to `nix-homebrew.taps` configuration, then rebuild. Taps are managed as read-only symlinks to /nix/store.

## Nix Formatting

Automated formatting with pre-commit hooks using `pre-commit-hooks.nix`.

**Setup**: Run `nix develop` once to install hooks. After setup, `nixfmt` and `statix` automatically run on all `.nix` files before each commit.

**Manual commands**:
- `nixfmt <file.nix>` - Format single file
- `nixfmt-tree` - Format entire directory recursively
- `statix check .` - Lint all Nix files

**Configuration**: Hooks configured in `flake.nix` under `devShells.aarch64-darwin.default`.

## Common Gotchas and Troubleshooting

### Build & System Issues

#### Darwin Rebuild Requires Sudo

**Important**: `darwin-rebuild switch` requires sudo for system activation as of recent nix-darwin versions.

**Symptoms**:
```
/run/current-system/sw/bin/darwin-rebuild: system activation must now be run as root
```

**Solution**:
Always run `darwin-rebuild switch` with sudo:
```bash
sudo darwin-rebuild switch --flake ~/.nixpkgs
```

**Note**: The shell aliases `rebuild` and `update-all` already include sudo, so you can use them directly without prefixing sudo.

**Exception**: `darwin-rebuild build` (without switch) does NOT require sudo since it only builds without activating the system.

#### Managing Large Package Builds

When updating packages, some large derivations can take 20-30 minutes to build from source (e.g., terraform, claude-code). Be patient - the build is likely still progressing even without output. Check progress with `ps aux | /usr/bin/grep darwin-rebuild`.

### Nix Configuration Issues

#### Git Aliases in Nix

When defining git aliases in `modules/home-manager/git/default.nix`:
- **Must use single-line strings**: Multiline strings with `''` will create invalid gitconfig entries with literal newlines
- **Escape quotes properly**: Use `\"` for quotes within the alias string
- **Join with semicolons**: Use `;` to separate shell commands instead of newlines
- **Example**: `wt = "!f() { cmd1; cmd2; cmd3; }; f";` ✓ NOT `wt = ''...multiline...''` ✗

#### Adding New Files to Flakes

When creating new modules or configuration files:
- **Must run `git add`**: Nix flakes only see files tracked by git
- **Error symptom**: "path does not exist" even though file is present
- **Solution**: `git add <new-file>` before running `darwin-rebuild`

#### Duplicate Option Definitions

When importing multiple modules that configure the same programs:
- **Problem**: "option is defined multiple times" errors
- **Common culprits**: starship, fzf, neovim when configured in multiple places
- **Solution**: Configure shared tools once in one shell module (e.g., `zsh/default.nix`), enable integrations in other shells

#### Removing Unused Flake Inputs

To clean up unused flake dependencies:
1. Remove from `flake.nix` inputs and specialArgs
2. Remove corresponding entries from `modules/common.nix` in `environment.etc`
3. Run `nix flake update` to update lock file
4. Run `darwin-rebuild switch` to apply

### Shell Configuration Issues

#### Switching Default Shell

To change the default shell:
1. **In Nix configuration**:
   - Edit `modules/common.nix`, set `user.shell = pkgs.<shell>;`
   - Enable in darwin: Set `programs.<shell>.enable = true` in `modules/darwin/default.nix`
   - Run `darwin-rebuild switch --flake ~/.nixpkgs`

2. **In macOS (for terminal windows)**:
   - The shell must be listed in `/etc/shells` (managed by nix-darwin)
   - Run: `chsh -s /run/current-system/sw/bin/<shell>`
   - Example: `chsh -s /run/current-system/sw/bin/fish`
   - **Important**: Use the `/run/current-system/sw/bin/` path, not the user profile path
   - Enter your password when prompted
   - Close and reopen terminal windows for the change to take effect

**Current configuration**:
- Fish (default in Nix config)
- Zsh (alternative, still available)
- Both enabled in `modules/darwin/default.nix`

**Common error**: `chsh: non-standard shell` means the shell path isn't in `/etc/shells`. Use the system path (`/run/current-system/sw/bin/fish`) which is automatically added by nix-darwin.

#### oh-my-zsh Plugin Conflicts

The oh-my-zsh git plugin automatically creates aliases for git aliases (e.g., `gwt` from `git wt`). This conflicts when defining functions with the same name. Solution: Add `unalias <name> 2>/dev/null || true` before function definitions in `modules/home-manager/zsh/default.nix`.

#### Python3 Symlink Issue

**Problem**: The `python3` command doesn't find installed packages, but `python3.13` works.

**Root cause**: The `python3` symlink doesn't properly initialize `sys.path`, using base Python's site-packages instead of the environment packages.

**Solution**: Created wrapper scripts (`python3-wrapper`, `python-wrapper`) in `modules/home-manager/default.nix` that execute `python3.13` directly. Shell aliases make these transparent. When adding Python packages, update both the `withPackages` list AND wrapper scripts.

#### Fish Shell Completions

See dedicated "Fish Shell Completions" section above for full details. Key points: Disable home-manager's `generateCompletions` (shadows real completions with helper functions), configure completion paths correctly, prepend Homebrew completions, and don't run `fish_update_completions`.

#### Shell Color Configuration

**Issue**: `ls` and `ll` commands don't show colors.

**Root cause**: `LS_COLORS` was set to BSD/macOS format, but GNU ls requires GNU format.

**Solution**: Set proper GNU `LS_COLORS` in `modules/home-manager/fish/default.nix` (e.g., `di=34:ln=35:ex=31`). Combined with shell aliases (`ls = "ls --color=auto"`), this provides colored output.

#### GUI App PATH Configuration

**Issue**: GUI apps (like Lens) can't find command-line tools from Nix.

**Root cause**: macOS GUI apps inherit environment from `launchd`, not shell configs.

**Solution**: Configure `launchd.user.envVariables.PATH` in `modules/darwin/default.nix` to include Homebrew and Nix paths. Must log out/in for launchd environment changes to take effect.

### Homebrew Issues

#### Homebrew Deprecated Taps

**Problem**: Homebrew deprecated `homebrew/cask-fonts` and `homebrew/cask-versions` taps.

**Solution**:
1. Migrate installed casks: `brew reinstall --cask <font-name>`
2. Force untap if needed: `brew untap --force homebrew/cask-fonts`
3. Remove from `modules/darwin/apps.nix` under `homebrew.taps`
4. Rebuild with `darwin-rebuild switch`

Fonts and versioned casks are now in `homebrew/cask`. No custom taps are currently configured.

#### Homebrew Package Renames

**Issue**: Homebrew occasionally renames casks (e.g., `wireshark` → `wireshark-app`).

**Solution**:
1. Update cask name in `modules/darwin/apps.nix`
2. Rebuild configuration: `sudo darwin-rebuild switch --flake ~/.nixpkgs`
3. Uninstall old package: `brew uninstall --cask wireshark`
4. Reinstall with new name: `brew install --cask wireshark-app`

### Package-Specific Issues

#### Google Cloud SDK / gsutil Cryptography Error

**Issue**: Running `gsutil` commands fails with cryptography error.

**Root cause**: Nix `google-cloud-sdk` package has broken Python cryptography library bindings to OpenSSL.

**Solution**: Switch to Homebrew's `gcloud-cli` cask:
1. Remove `google-cloud-sdk` from `modules/home-manager/default.nix`
2. Add `gcloud-cli` to `modules/darwin/apps.nix` casks
3. Add `/opt/homebrew/share/google-cloud-sdk/bin` to `home.sessionPath` in both fish and zsh configs
4. Rebuild and restart shell

Benefits: Properly built cryptography bindings, better macOS integration, includes all components (gcloud, gsutil, bq, gke-gcloud-auth-plugin), auto-updates with `darwin-rebuild switch`.
