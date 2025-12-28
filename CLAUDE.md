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
```

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

- **Inputs**: Defines dependencies (nixpkgs unstable, home-manager, nix-darwin)
- **Outputs**: Generates darwin configurations using helper functions `mkDarwinConfig` and `mkHomeConfig`
- **Darwin Configuration**: `uber-mac` for aarch64-darwin (Apple Silicon)
- **Simplified**: Removed unused flake inputs (stable nixpkgs, comma, devshell, flake-compat, flake-utils) for faster rebuilds

### Module System

The repository uses a layered module architecture:

1. **modules/primary.nix**: Defines `user` and `hm` (home-manager) option aliases, allowing shorthand config like `user.name` instead of `users.users.<name>.name`

2. **modules/common.nix**: Shared configuration imported by both Darwin and home-manager
   - Essential system utilities only (coreutils-full, curl, wget, git)
   - User shell configuration (fish as default)
   - Home-manager bootstrap with global nixpkgs

3. **modules/darwin/default.nix**: Darwin-specific base configuration
   - System settings (stateVersion, primaryUser)
   - Zsh configuration
   - nixpkgs.config (allowUnfree, allowBroken, allowUnsupportedSystem)
   - Documentation disabled for performance

4. **modules/darwin/apps.nix**: Homebrew configuration for GUI apps
   - Casks: JetBrains Toolbox, VS Code, Firefox, Spotify, Signal, Slack, etc.
   - Brews: gnupg2, pinentry-mac

5. **modules/home-manager/default.nix**: Home-manager user environment
   - Imports CLI, git, and fish configurations
   - Defines user packages (rust tooling, kubernetes tools, nodejs, terraform, etc.)
   - Python3 with packages: ipython, asyncpg, requests
   - Tmux configuration with plugins (cpu, resurrect)
   - macOS application linking activation script

6. **Specialized modules**:
   - `modules/home-manager/cli/default.nix`: Shell configuration (zsh, starship, fzf, neovim)
   - `modules/home-manager/git/default.nix`: Git configuration with enhanced worktree workflow
   - `modules/home-manager/fish/default.nix`: Fish shell configuration (now the default shell)

### Profile System

Profiles compose modules for specific use cases:

- **profiles/personal.nix**: Sets `user.name = "palicand"` and imports home-manager/personal.nix
- Applied to the `uber-mac` configuration in flake.nix

### Key Patterns

- **User Aliasing**: The `primary.nix` module allows `user.*` and `hm.*` as shortcuts to `users.users.<username>.*` and `home-manager.users.<username>.*`
- **Input Following**: Both home-manager and nix-darwin follow the same nixpkgs input for consistency
- **Single nixpkgs**: Uses nixpkgs unstable channel exclusively for all packages
- **Platform Abstraction**: `homePrefix` function handles /Users (macOS) vs /home (Linux) paths

## Common Modifications

### Adding System Packages

Add to `modules/common.nix` under `environment.systemPackages` for essential system utilities only, or to `modules/home-manager/default.nix` under `home.packages` for user-specific packages.

### Adding Python Packages

To add Python packages globally:
1. Edit `modules/home-manager/default.nix`
2. Find the `python3.withPackages` expression (around line 107)
3. Add the package name to the list within the `with ps;` block
4. **IMPORTANT**: Also add it to the wrapper scripts (lines 114-119) to keep them in sync
5. Run `darwin-rebuild switch --flake ~/.nixpkgs` to apply changes

Example:
```nix
(python3.withPackages (ps: with ps; [
  ipython
  asyncpg
  requests  # Added package
]))

# Also update the wrapper scripts:
(pkgs.writeShellScriptBin "python3-wrapper" ''
  exec ${pkgs.python3.withPackages (ps: with ps; [ ipython asyncpg requests ])}/bin/python3.13 "$@"
'')
```

**Why wrapper scripts are needed**: The `python3` symlink in Nix Python environments has a known issue where it doesn't properly initialize `sys.path`, causing it to use the base Python libraries instead of the environment with your installed packages. The `python3.13` binary works correctly, so we use wrapper scripts that call it directly. Shell aliases (`python3` → `python3-wrapper`) make this transparent.

### Adding Homebrew Apps

Modify `modules/darwin/apps.nix`:
- GUI apps: add to `homebrew.casks`
- CLI tools: add to `homebrew.brews`

### Modifying Shell Configuration

Edit `modules/home-manager/cli/default.nix`:
- Shell aliases in `programs.zsh.shellAliases`
- Environment variables in `programs.zsh.localVariables`
- Shell initialization in `programs.zsh.initExtra`

### Changing User Settings

The primary user is "palicand" defined in:
- `modules/darwin/default.nix` (`system.primaryUser`)
- `profiles/personal.nix` (`user.name`)

## Important Configuration Details

- **State Version**: home-manager uses "25.11", darwin uses state version 6
- **Garbage Collection**: Automatic, runs daily at 1:30 PM, deletes generations older than 14 days
- **Experimental Features**: nix-command and flakes enabled
- **Default Shell**: Fish (configured in `modules/common.nix`)
- **Alternative Shells**: Zsh is still configured and available
- **Python Environment**: Python 3.13.9 with ipython, asyncpg, and requests
- **Shell Aliases**:
  - `rebuild` → `sudo darwin-rebuild switch --flake ~/.nixpkgs` (requires sudo for system activation)
  - `update-all` → `nix flake update --flake ~/.nixpkgs && sudo darwin-rebuild switch --flake ~/.nixpkgs` (updates all flakes and rebuilds)
  - `grep` → `rg` (ripgrep)
  - `cat` → `bat`
  - `ls` → `ls --color=auto` (GNU ls with colors)
  - `ll` → `ls -lah --color=auto` (long listing with colors)
  - `cp` → `cp --reflink=auto` (use copy-on-write when possible)
  - `k` → `kubectl`
- **Fish Shell Configuration**:
  - Welcome message disabled via `set -g fish_greeting` in `modules/home-manager/fish/default.nix`
  - Tab completion paths fixed via `conf.d/zzz_completion_paths.fish` - adds Fish built-ins (1000+ commands) and Homebrew paths that home-manager doesn't include by default
  - Atuin shell history integration for smart, frequency-based command search
- **GUI App Environment**: `launchd.user.envVariables.PATH` configured to include Homebrew and Nix paths so GUI apps (like Lens) can find command-line tools
- **Homebrew on Activation**: `onActivation.upgrade = true` in `modules/darwin/apps.nix` - automatically upgrades all Homebrew packages when running `darwin-rebuild switch`

## Git Worktree Workflow

This configuration includes an enhanced git worktree workflow for parallel development:

### `git wt` alias

Creates a new worktree with automatic secret/config copying:

```bash
git wt <dir-suffix> <branch-name>
```

**Features:**
- Creates worktree in parent directory as `<repo-name>-<dir-suffix>`
- Automatically copies relevant git-ignored config files (`.env`, `.vscode`, `.idea`, `.gradle`, `.properties`, `.yaml`, `.yml`, `.json`) to the new worktree
- Uses `rsync` with `--info=progress2` to show overall progress (percentage, speed, ETA) when copying files
- Shows file count before copying and completion message after
- Uses `origin/main` or `origin/master` as the base branch
- Example: `git wt feature-123 feat/my-feature` creates `backend-platform-feature-123`

### `gwt` function

Wrapper around `git wt` that automatically `cd`s into the new worktree:

```bash
gwt <dir-suffix> <branch-name>
```

**Usage Example:**
```bash
gwt extension-error BKBN-3828-my-feature
# Creates worktree and immediately cd's into it
```

This is particularly useful for:
- Testing features in isolation with separate environment configs
- Working on multiple branches simultaneously
- Quick context switching without stashing changes

### Implementation Notes

- The `git wt` alias is defined in `modules/home-manager/git/default.nix`
- The `gwt` function is defined in `modules/home-manager/cli/default.nix` (Zsh) and `modules/home-manager/fish/default.nix` (Fish)
- **Important**: Git aliases in Nix must be single-line strings, not multiline. Use semicolons and proper escaping.
- **oh-my-zsh conflict**: The git plugin auto-creates a `gwt` alias from the `git wt` alias. The Zsh function includes `unalias gwt` to handle this.
- **Performance**: Uses `rsync` instead of `cp` for faster copying with progress display, especially useful for projects with many config files

## Notable Packages

- **Development**: rustup, nodejs, yarn, jdk21, poetry, cmake
- **Python Tools**: uv (fast package installer), ipython, asyncpg, requests
- **Cloud/DevOps**: google-cloud-sdk (with GKE auth plugin), kubernetes-helm, k9s, terraform, stripe-cli
- **Database**: postgresql_14, pgcli
- **CLI Tools**: ripgrep, bat, fzf, jq, yq, htop, tree, tig, ffmpeg, jwt-cli
- **Terminal**: tmux (with cpu, resurrect, sensible, yank plugins)
- **AI**: claude-code
- **GUI Apps** (Homebrew): JetBrains Toolbox, Lens, Postman, VS Code, Firefox, Spotify, Signal, Slack, Stats, Alfred, KeePassXC, iTerm2, iter.ai, CrossOver, BetterDisplay, Mullvad VPN, 1Password, GitHub Desktop, Iosevka Nerd Font

## Nix Formatting

Use `nixpkgs-fmt` (installed in environment.systemPackages) to format Nix files:

```bash
nixpkgs-fmt <file.nix>
```

## Common Gotchas and Troubleshooting

### Darwin Rebuild Requires Sudo

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

### Git Aliases in Nix

When defining git aliases in `modules/home-manager/git/default.nix`:
- **Must use single-line strings**: Multiline strings with `''` will create invalid gitconfig entries with literal newlines
- **Escape quotes properly**: Use `\"` for quotes within the alias string
- **Join with semicolons**: Use `;` to separate shell commands instead of newlines
- **Example**: `wt = "!f() { cmd1; cmd2; cmd3; }; f";` ✓ NOT `wt = ''...multiline...''` ✗

### oh-my-zsh Plugin Conflicts

The oh-my-zsh git plugin automatically creates aliases for git aliases (e.g., `gwt` from `git wt`):
- **Problem**: This conflicts when defining functions with the same name
- **Solution**: Add `unalias <name> 2>/dev/null || true` before function definitions
- **Location**: `modules/home-manager/cli/default.nix` in `initContent`

### Adding New Files to Flakes

When creating new modules or configuration files:
- **Must run `git add`**: Nix flakes only see files tracked by git
- **Error symptom**: "path does not exist" even though file is present
- **Solution**: `git add <new-file>` before running `darwin-rebuild`

### Switching Default Shell

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

### Duplicate Option Definitions

When importing multiple modules that configure the same programs:
- **Problem**: "option is defined multiple times" errors
- **Common culprits**: starship, fzf, neovim when configured in multiple places
- **Solution**: Configure shared tools once in `cli/default.nix`, enable integrations in other shells
- **Example**: starship configured in `cli`, fish uses the same config automatically

### Removing Unused Flake Inputs

To clean up unused flake dependencies and speed up rebuilds:
1. **Remove from inputs**: Edit `flake.nix` and remove unused input definitions
2. **Remove specialArgs**: Remove references from `specialArgs` in `mkDarwinConfig` and `mkHomeConfig`
3. **Remove etc sources**: Remove corresponding entries from `modules/common.nix` in `environment.etc`
4. **Update flake lock**: Run `nix flake update` to update the lock file (will show removed inputs)
5. **Rebuild**: Run `darwin-rebuild switch` to apply changes

**Recent cleanup** (2025-12-19):
- Removed: `stable` (nixos-23.05), `comma`, `devshell`, `flake-compat`, `flake-utils`
- Benefit: Faster rebuilds, smaller flake.lock, no unnecessary dependency downloads

### Managing Large Package Builds

When updating packages, some large derivations can take 20-30 minutes to build from source:
- **terraform**: Go modules compilation can be slow
- **claude-code**: npm dependencies are extensive
- **Solution**: Be patient, the build is likely still progressing even without output
- **Check progress**: Use `ps aux | /usr/bin/grep darwin-rebuild` to verify the process is still running
- **Background option**: Large rebuilds can be run with `run_in_background: true`

### Python3 Symlink Issue

**Problem**: The `python3` command doesn't find installed packages (like `requests`, `ipython`), but `python3.13` works correctly.

**Root cause**: The `python3` symlink in Nix Python environments doesn't properly initialize `sys.path`. When executed, it uses the base Python's site-packages instead of the environment with your installed packages.

**Symptoms**:
```bash
python3 -c "import requests"  # ModuleNotFoundError
python3.13 -c "import requests"  # Works fine
```

**Solution implemented** (2025-12-19):
1. Created wrapper scripts in `modules/home-manager/default.nix`:
   - `python3-wrapper` - Executes `python3.13` with correct environment
   - `python-wrapper` - Same for `python` command
2. Added shell aliases in both Fish and Zsh configurations:
   - `python` → `python-wrapper`
   - `python3` → `python3-wrapper`
3. Result: `python3` command now works correctly in interactive shells

**Technical details**:
- Direct execution: `/nix/store/.../python3-3.13.9-env/bin/python3.13` ✅ Works
- Symlink execution: `/nix/store/.../python3-3.13.9-env/bin/python3` ❌ Broken `sys.path`
- Wrapper script: Shell script that `exec`s `python3.13` ✅ Works everywhere

**When adding new Python packages**: Update both the `withPackages` list AND the wrapper scripts to keep them in sync (see "Adding Python Packages" section).

### Homebrew Deprecated Taps

**Problem**: Homebrew deprecated `homebrew/cask-fonts` and `homebrew/cask-versions` taps (merged into main `homebrew/cask` tap). If these taps are listed in your Nix configuration, `brew update` will fail with errors like:
```
Error: homebrew/homebrew-cask-versions does not exist! Run `brew untap homebrew/homebrew-cask-versions` to remove it.
Error: homebrew/homebrew-cask-fonts does not exist! Run `brew untap homebrew/homebrew-cask-fonts` to remove it.
```

**Root cause**:
1. Nix-darwin manages Homebrew taps via `modules/darwin/apps.nix` in the `homebrew.taps` list
2. The deprecated taps were included in the configuration
3. Homebrew can't untap them if casks are still installed from those taps (e.g., font-iosevka-nerd-font)

**Solution** (2025-12-21):
1. **Migrate installed casks**: If you have fonts or versioned casks installed from the old taps:
   ```bash
   # Reinstall to migrate from old tap to new location
   brew reinstall --cask font-iosevka-nerd-font
   ```

2. **Force untap if needed**: If Homebrew still refuses to untap:
   ```bash
   brew untap --force homebrew/cask-fonts
   brew untap --force homebrew/cask-versions
   ```

3. **Remove from Nix config**: Edit `modules/darwin/apps.nix` and remove the deprecated taps from `homebrew.taps`:
   ```nix
   taps = [
     "homebrew/bundle"
     "homebrew/services"
     # Removed: "homebrew/cask-fonts" (deprecated)
     # Removed: "homebrew/cask-versions" (deprecated)
   ];
   ```

4. **Rebuild**: Run `darwin-rebuild switch --flake ~/.nixpkgs` to apply changes

**Current supported taps**:
- `homebrew/bundle` - For Brewfile support
- `homebrew/services` - For service management

**Note**: Fonts and versioned casks are now available directly through `homebrew/cask` without needing separate taps.

### Fish Shell Completions

**Issue**: Tab completions don't work for some commands (brew, gradle, gradlew) in Fish shell.

**Root Cause** (2025-12-28):

**Generated completions shadow real ones**:
- home-manager's `generateCompletions` option (default: enabled) creates simple completions from man pages
- Fish's `fish_update_completions` command also generates a cache in `~/.cache/fish/generated_completions/`
- Generated completions are basic `complete -c` commands without helper functions
- Real completion files (like brew.fish, gradle.fish) define helper functions that are required for completions to work
- Generated completions appear early in `fish_complete_path`, shadowing the real ones
- Fish loads the generated file and stops → helper functions never get defined → completions fail

**Solution** (2025-12-28):

**Step 1**: Disable generated completions in `modules/home-manager/fish/default.nix`:
```nix
programs.fish = {
  enable = true;
  generateCompletions = false;  # Disable - generated completions shadow real ones with helper functions
  # ...
};
```

**Step 2**: Add completion paths in `modules/home-manager/default.nix` with correct priority:
```nix
"fish/conf.d/zzz_completion_paths.fish".text = ''
  # Add Fish's built-in completions directory (1000+ commands: git, npm, etc.)
  set -l builtin_completions $__fish_data_dir/completions
  if test -d $builtin_completions; and not contains $builtin_completions $fish_complete_path
    set -ga fish_complete_path $builtin_completions
  end

  # PREPEND Homebrew completions so they take priority over Fish's placeholder files
  # (Fish's built-in brew.fish is just a comment pointing to Homebrew's upstream)
  if test -d /opt/homebrew/share/fish/vendor_completions.d
    and not contains /opt/homebrew/share/fish/vendor_completions.d $fish_complete_path
    set -p fish_complete_path /opt/homebrew/share/fish/vendor_completions.d
  end
'';

# gradlew.fish - Load gradle.fish which provides completions for both gradle and gradlew
"fish/completions/gradlew.fish".text = ''
  # gradle.fish defines completions for both 'gradle' and 'gradlew' commands
  # But Fish's lazy loading doesn't know this - it only looks for gradlew.fish when you type gradlew
  # So we explicitly source gradle.fish to make both sets of completions available
  set -l gradle_completion $__fish_data_dir/completions/gradle.fish
  test -f $gradle_completion; and source $gradle_completion
'';
```

**Step 3**: Clear Fish's generated cache (one-time):
```bash
rm -rf ~/.cache/fish/generated_completions/
```

**Important**: Do NOT run `fish_update_completions` - it regenerates the cache and breaks completions again.

**What this fixes**:
- ✅ Homebrew tools (brew, etc.) - real completions loaded instead of placeholders
- ✅ Git, npm, kubectl, terraform - Fish's lazy loading works correctly
- ✅ Gradle - Fish's gradle.fish loads with helper functions
- ✅ Gradlew - Custom wrapper sources gradle.fish when gradlew is used

**Why gradlew needs special handling**:
- Fish's builtin `gradlew.fish` contains only: `complete -c gradlew -w gradle`
- This wrapping syntax requires gradle completions to already be loaded
- Fish's lazy loading doesn't know that `gradle.fish` provides `gradlew` completions
- When you type `gradlew <tab>`, Fish looks for `gradlew.fish` but doesn't load `gradle.fish`
- Solution: Create custom `gradlew.fish` that explicitly sources `gradle.fish`

**Key learnings**:
- Fish's lazy loading works perfectly when the right file is found first
- Generated completions are problematic because they shadow real ones with helper functions
- Use `set -p` (prepend) for Homebrew to override Fish's placeholder files
- Some completions (gradlew) need explicit sourcing because lazy loading can't infer dependencies

**Sources**:
- [Fish completions documentation](https://fishshell.com/docs/current/completions.html)
- [home-manager fish.nix source](https://github.com/nix-community/home-manager/blob/master/modules/programs/fish.nix)

### GUI App PATH Configuration

**Issue**: GUI applications (like Lens) can't find command-line tools from Nix (e.g., `gke-gcloud-auth-plugin`).

**Root cause**: macOS GUI apps inherit their environment from `launchd`, not from shell configurations. By default, they don't have Nix paths in their PATH.

**Solution** (2025-12-26):
Configure `launchd.user.envVariables.PATH` in `modules/darwin/default.nix`:

```nix
# Set PATH for GUI applications (like Lens) so they can find Nix-managed binaries
launchd.user.envVariables.PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:${config.environment.systemPath}";
```

This sets the PATH environment variable in your user's launchd environment, making Nix-managed tools available to all GUI apps.

**Important**: After applying this change, you must **log out and log back in** (or reboot) for launchd environment changes to take effect.

### Shell Color Configuration

**Issue**: `ls` and `ll` commands don't show colors even though GNU ls from Nix supports `--color=auto`.

**Root cause**: `LS_COLORS` was set to BSD/macOS format (`ExFxBxDxCxegedabagacad`), but GNU ls requires a different format.

**Solution** (2025-12-26):
Set proper GNU `LS_COLORS` in `modules/home-manager/fish/default.nix`:

```fish
# GNU ls color settings (not BSD LSCOLORS format)
set -gx LS_COLORS 'di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
```

This uses the GNU format where:
- `di=34` - directories in blue
- `ln=35` - symlinks in magenta
- `ex=31` - executables in red
- etc.

Combined with shell aliases (`ls = "ls --color=auto"`), this provides colored output for both `ls` and `ll` commands.
