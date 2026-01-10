{ pkgs, ... }:
let
  shared = import ../shared.nix;
in
{
  home.sessionPath = shared.sessionPath;

  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        # Sync history across machines (requires atuin account)
        auto_sync = false;
        # Search mode: prefix, fulltext, fuzzy, skim
        search_mode = "fuzzy";
        # Filter mode for search
        filter_mode = "global";
        # Show preview of command
        show_preview = true;
        # Use Ctrl+R for atuin instead of default Fish history
        inline_height = 30;
        # Style: auto, full, compact
        style = "compact";
      };
    };

    fish = {
      enable = true;
      generateCompletions = false; # Disable - generated completions shadow real ones with helper functions

      shellAliases = shared.aliases;

      shellInit = ''
        # Disable fish welcome message
        set -g fish_greeting

        # Environment variables
        set -gx LANG en_US.UTF-8
        set -gx CLICOLOR 1
        # GNU ls color settings (not BSD LSCOLORS format)
        set -gx LS_COLORS 'di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
        set -gx TERM xterm-256color

        # Homebrew shell environment (macOS)
        if test -d /opt/homebrew
          eval (/opt/homebrew/bin/brew shellenv)
        end

        # GPG agent for SSH
        set -gx GPG_TTY (tty)
        set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
      '';

      interactiveShellInit = ''
        # Kubectl completion
        kubectl completion fish | source

        # Temporary nix shell with packages
        # Usage: nix-temp jq ripgrep fd
        # Automatically prepends nixpkgs# if no flake source specified
        function nix-temp
          if test (count $argv) -eq 0
            echo "Usage: nix-temp <package> [package...]"
            echo "Example: nix-temp jq ripgrep"
            echo "         nix-temp jq github:owner/repo#pkg"
            return 1
          end

          set -l packages
          for pkg in $argv
            if string match -q '*#*' $pkg
              # Already has flake reference
              set -a packages $pkg
            else
              # Prepend nixpkgs#
              set -a packages "nixpkgs#$pkg"
            end
          end

          echo "Launching shell with: $packages"
          nix shell $packages
        end

        # Git worktree wrapper - creates worktree with config copy and cds into it
        # Usage: gcwt <dir-suffix> <branch-name>
        # Example: gcwt feature-123 feat/my-feature
        # Note: plugin-git automatically creates 'gcwt' abbreviation for 'git cwt'
        function gcwt
          if test (count $argv) -ne 2
            echo "Usage: gcwt <dir-suffix> <branch-name>"
            echo "Example: gcwt feature-123 feat/my-feature"
            return 1
          end

          set worktree_dir (git cwt $argv[1] $argv[2] | tail -n 1)
          if test -d "$worktree_dir"
            cd "$worktree_dir"
          end
        end
      '';

      plugins = [
        {
          name = "z";
          inherit (pkgs.fishPlugins.z) src;
        }
        {
          name = "fzf-fish";
          inherit (pkgs.fishPlugins.fzf-fish) src;
        }
        {
          name = "done";
          inherit (pkgs.fishPlugins.done) src;
        }
        {
          name = "autopair";
          inherit (pkgs.fishPlugins.autopair) src;
        }
        {
          name = "plugin-git";
          inherit (pkgs.fishPlugins.plugin-git) src;
        }
      ];
    };
  };
}
