# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal Nix configuration repository for managing macOS (nix-darwin) and home-manager configurations. It uses Nix flakes to define declarative system configurations, user environments, and package installations.

## Core Commands

### Building and Applying Configuration

```bash
# Rebuild and switch macOS configuration (primary command)
darwin-rebuild switch --flake ~/.nixpkgs

# Or use the shell alias
rebuild

# Build without switching (for testing)
darwin-rebuild build --flake ~/.nixpkgs

# Check what would change without applying
darwin-rebuild build --flake ~/.nixpkgs
nix store diff-closures /run/current-system ./result
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

- **Inputs**: Defines dependencies (nixpkgs unstable, stable 23.05, home-manager, nix-darwin)
- **Outputs**: Generates darwin configurations using helper functions `mkDarwinConfig` and `mkHomeConfig`
- **Darwin Configuration**: `uber-mac` for aarch64-darwin (Apple Silicon)

### Module System

The repository uses a layered module architecture:

1. **modules/primary.nix**: Defines `user` and `hm` (home-manager) option aliases, allowing shorthand config like `user.name` instead of `users.users.<name>.name`

2. **modules/common.nix**: Shared configuration imported by both Darwin and home-manager
   - Base system packages (neovim, git, coreutils, curl, wget, jq, bat, fzf)
   - Python3 with ipython and asyncpg
   - User shell configuration (zsh)
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
   - Imports CLI, git, and alacritty configurations
   - Defines user packages (rust tooling, kubernetes tools, nodejs, terraform, etc.)
   - Tmux configuration with plugins
   - macOS application linking activation script

6. **Specialized modules**:
   - `modules/home-manager/cli/default.nix`: Shell configuration (zsh, starship, fzf, neovim)
   - `modules/home-manager/git/default.nix`: Git configuration
   - `modules/home-manager/alacritty/default.nix`: Terminal emulator config

### Profile System

Profiles compose modules for specific use cases:

- **profiles/personal.nix**: Sets `user.name = "palicand"` and imports home-manager/personal.nix
- Applied to the `uber-mac` configuration in flake.nix

### Key Patterns

- **User Aliasing**: The `primary.nix` module allows `user.*` and `hm.*` as shortcuts to `users.users.<username>.*` and `home-manager.users.<username>.*`
- **Input Following**: Both home-manager and nix-darwin follow the same nixpkgs input for consistency
- **Dual nixpkgs**: Uses both unstable (default) and stable (23.05) channels, accessible via `inputs.nixpkgs` and `inputs.stable`
- **Platform Abstraction**: `homePrefix` function handles /Users (macOS) vs /home (Linux) paths

## Common Modifications

### Adding System Packages

Add to `modules/common.nix` under `environment.systemPackages` for system-wide packages, or to `modules/home-manager/default.nix` under `home.packages` for user-specific packages.

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

- **State Version**: home-manager uses "23.05", darwin uses state version 4
- **Garbage Collection**: Automatic, deletes generations older than 14 days
- **Experimental Features**: nix-command is enabled in darwin-configuration.nix
- **Shell Aliases**:
  - `rebuild` → `darwin-rebuild switch --flake ~/.nixpkgs`
  - `grep` → `rg` (ripgrep)
  - `cat` → `bat`
  - `k` → `kubectl`

## Notable Packages

- **Development**: rustup, nodejs, yarn, jdk21, poetry, cmake
- **Cloud/DevOps**: google-cloud-sdk (with GKE auth), kubernetes-helm, k9s, terraform, stripe-cli
- **Database**: postgresql_14, pgcli
- **CLI Tools**: ripgrep, bat, fzf, jq, yq, htop, tree, tig, ffmpeg, jwt-cli
- **Terminal**: alacritty, tmux (with cpu and resurrect plugins)
- **AI**: claude-code

## Nix Formatting

Use `nixpkgs-fmt` (installed in environment.systemPackages) to format Nix files:

```bash
nixpkgs-fmt <file.nix>
```
