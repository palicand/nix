{ config, pkgs, ... }:
let
  shared = import ../shared.nix;
in
{
  # Shared paths plus Zsh-specific paths
  home.sessionPath = shared.sessionPath ++ [
    "$HOME/.antigravity/antigravity/bin"
  ];

  programs = {
    gpg.enable = true;

    zsh = {
      localVariables = {
        LANG = "en_US.UTF-8";
        CLICOLOR = 1;
        LS_COLORS = "ExFxBxDxCxegedabagacad";
        TERM = "xterm-256color";
      };

      enable = true;
      autocd = true;
      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-autosuggestions"; }
        ];
      };
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "sudo"
          "common-aliases"
          "yarn"
          "docker"
          "npm"
          "dotenv"
        ];
      };
      initContent = ''
        # Homebrew shell environment (macOS)
        if [[ -d /opt/homebrew ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        # glab: PAT from sops, not OAuth (OAuth races under concurrent calls)
        if [[ -r /run/secrets/gitlab_pat ]]; then
          export GITLAB_TOKEN="$(cat /run/secrets/gitlab_pat)"
        fi

        # Homebrew authenticates api.github.com with this (raises the IP's 60 req/hr
        # unauthenticated cap to 5000), so brew update/cask checks stop exhausting
        # the shared GitHub rate limit.
        if [[ -r /run/secrets/github_token ]]; then
          export HOMEBREW_GITHUB_API_TOKEN="$(cat /run/secrets/github_token)"
        fi

        # bkbn tooling/skills read these as env vars (sops-managed, not universal vars)
        if [[ -r /run/secrets/gitlab_deploy_token ]]; then
          export GITLAB_DEPLOY_TOKEN="$(cat /run/secrets/gitlab_deploy_token)"
        fi
        if [[ -r /run/secrets/gitlab_deploy_user ]]; then
          export GITLAB_DEPLOY_USER="$(cat /run/secrets/gitlab_deploy_user)"
        fi
        if [[ -r /run/secrets/notion_api_key ]]; then
          export NOTION_API_KEY="$(cat /run/secrets/notion_api_key)"
        fi
        if [[ -r /run/secrets/slack_bot_token ]]; then
          export SLACK_BOT_TOKEN="$(cat /run/secrets/slack_bot_token)"
        fi

        # iTerm2 shell integration
        test -e "$HOME/.iterm2_shell_integration.zsh" && source "$HOME/.iterm2_shell_integration.zsh"

        # Kubectl completion
        source <(kubectl completion zsh)
        complete -F __start_kubectl k

        # Temporary nix shell with packages
        # Usage: nix-temp jq ripgrep fd
        # Automatically prepends nixpkgs# if no flake source specified
        nix-temp() {
          if [[ $# -eq 0 ]]; then
            echo "Usage: nix-temp <package> [package...]"
            echo "Example: nix-temp jq ripgrep"
            echo "         nix-temp jq github:owner/repo#pkg"
            return 1
          fi

          local packages=()
          for pkg in "$@"; do
            if [[ "$pkg" == *"#"* ]]; then
              # Already has flake reference
              packages+=("$pkg")
            else
              # Prepend nixpkgs#
              packages+=("nixpkgs#$pkg")
            fi
          done

          echo "Launching shell with: ''${packages[*]}"
          nix shell "''${packages[@]}"
        }

        # Git worktree wrapper - creates worktree with config copy and cds into it
        # Usage: gcwt <dir-suffix> <branch-name>
        # Example: gcwt feature-123 feat/my-feature
        # Unalias gcwt if oh-my-zsh git plugin created it
        unalias gcwt 2>/dev/null || true
        gcwt() {
          if [[ $# -ne 2 ]]; then
            echo "Usage: gcwt <dir-suffix> <branch-name>"
            echo "Example: gcwt feature-123 feat/my-feature"
            return 1
          fi

          local worktree_dir=$(git cwt "$1" "$2" | tail -n 1)
          if [[ -d "$worktree_dir" ]]; then
            cd "$worktree_dir"
          fi
        }

        # In a cmux pane, route `claude` to its teams surface (args pass through);
        # the agent-launch guard stops cmux re-dispatching the agent it launched.
        claude() {
          if [[ -n "$CMUX_SHELL_INTEGRATION" && -z "$CMUX_AGENT_LAUNCH_KIND" ]]; then
            cmux claude-teams "$@"
          else
            command claude "$@"
          fi
        }
      '';
      shellAliases = shared.aliases // {
        # Match fish plugin-git's force-push family; oh-my-zsh ships `gpf!`
        # (= --force) but not the safer --force-with-lease variants.
        "gp!" = "git push --force-with-lease";
        "ggp!" = ''git push --force-with-lease origin "$(git_current_branch)"'';
      };
    };

    starship = {
      enable = true;
      package = pkgs.starship;
      # To use a preset, run: starship preset <name> -o ~/.config/starship.toml
      # Available presets: bracketed-segments, gruvbox-rainbow, jetpack, nerd-font-symbols,
      #                    no-runtime-versions, pastel-powerline, plain-text-symbols, pure-preset, tokyo-night
      settings = {
        # Use default Starship format (includes all standard modules)
        # Disable GCP account display
        gcloud.disabled = true;

        # Enable Kubernetes context display
        kubernetes.disabled = false;
      };
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      # Atuin owns Ctrl-R; keep only fzf's Ctrl-T (file) and Alt-C (cd) widgets
      historyWidget.command = "";
    };

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
    };

    gitui = {
      enable = false;
    };

  };
}
