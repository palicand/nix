{ pkgs, ... }:
let
  shared = import ../shared.nix;

  # Fetch Homebrew Fish completions from upstream
  # nix-homebrew doesn't generate these, so we fetch directly from Homebrew's repo
  brewFishCompletions = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Homebrew/brew/4.5.3/completions/fish/brew.fish";
    sha256 = "sha256-mmIIh443OwNiMwewJAuSyovyEQmeXqAaObB8tWZbPZQ=";
  };
in
{
  xdg.configFile = {
    # Add Homebrew Fish completions (nix-homebrew doesn't generate these)
    "fish/completions/brew.fish".source = brewFishCompletions;

    # Auto-source .env files on directory change.
    # Walks up from cwd to find nearest .env, sources it, and tracks set vars
    # so they can be unset when leaving the tree.
    "fish/conf.d/autoenv.fish".text = ''
      set -g __autoenv_vars
      set -g __autoenv_loaded_dir

      function __autoenv_deactivate
          for var in $__autoenv_vars
              set -e $var
          end
          set -g __autoenv_vars
          set -g __autoenv_loaded_dir
      end

      function __autoenv_find_env
          set -l dir (pwd)
          while test -n "$dir"
              if test -f "$dir/.env"
                  echo "$dir/.env"
                  return 0
              end
              if test "$dir" = "/" -o "$dir" = "$HOME"
                  return 1
              end
              set dir (path dirname "$dir")
          end
          return 1
      end

      function __autoenv_activate -a env_file
          __autoenv_deactivate
          set -g __autoenv_loaded_dir (path dirname "$env_file")
          set -l vars
          while read -l line
              # Skip blank lines and comments
              if string match -qr '^\s*(#|$)' -- $line
                  continue
              end
              # Strip trailing inline comment (after unquoted whitespace + #)
              set line (string replace -r '\s+#.*$' "" -- $line)
              # Split on first =
              set -l pair (string split -m 1 '=' -- $line)
              if test (count $pair) -ne 2
                  continue
              end
              set -l key (string trim -- $pair[1])
              # Strip leading "export "
              set key (string replace -r '^export\s+' "" -- $key)
              # Validate key is identifier
              if not string match -qr '^[a-zA-Z_][a-zA-Z0-9_]*$' -- $key
                  continue
              end
              set -l value (string trim -- $pair[2])
              # Strip matching surrounding single or double quotes
              set value (string replace -r '^"(.*)"$' '$1' -- $value)
              set value (string replace -r "^'(.*)'\$" '$1' -- $value)
              set -gx $key $value
              set -a vars $key
          end < "$env_file"
          set -g __autoenv_vars $vars
      end

      function __autoenv_check --on-variable PWD
          set -l env_file (__autoenv_find_env)
          if test $status -eq 0
              set -l dir (path dirname "$env_file")
              # Still inside the tree we already loaded — nothing to do
              if test "$dir" = "$__autoenv_loaded_dir"
                  return
              end
              __autoenv_activate "$env_file"
          else if test -n "$__autoenv_loaded_dir"
              __autoenv_deactivate
          end
      end

      # Run once at shell startup for new interactive shells in env'd directories
      if status is-interactive
          __autoenv_check
      end
    '';

    # Ensure Nix paths come before Homebrew paths (runs last due to zzz prefix)
    # This fixes tools like uv detecting Homebrew's Python instead of Nix's
    "fish/conf.d/zzz_nix_path_priority.fish".text = ''
      # Prepend Nix paths to ensure they take priority over Homebrew
      # brew shellenv adds /opt/homebrew/bin to front, we need Nix first
      fish_add_path --prepend --move /etc/profiles/per-user/$USER/bin
      fish_add_path --prepend --move $HOME/.nix-profile/bin
    '';
  };
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

             if test -d (brew --prefix)"/share/fish/completions"
            set -p fish_complete_path (brew --prefix)/share/fish/completions
        end

        if test -d (brew --prefix)"/share/fish/vendor_completions.d"
            set -p fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
        end

                # GPG agent for SSH
                set -gx GPG_TTY (tty)
                set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)

                # iTerm2 shell integration
                test -e "$HOME/.iterm2_shell_integration.fish"; and source "$HOME/.iterm2_shell_integration.fish"
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
