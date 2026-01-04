{ config, pkgs, ... }:
{
  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "/opt/homebrew/share/google-cloud-sdk/bin"
  ];

  programs = {
    fish = {
      enable = true;
      generateCompletions = false;  # Disable - generated completions shadow real ones with helper functions

      shellAliases = {
        grep = "rg";
        cat = "bat";
        awk = "gawk";
        cp = "cp --reflink=auto";  # Use copy-on-write (CoW) when possible
        ls = "ls --color=auto";  # Enable colors for GNU ls
        ll = "ls -lah --color=auto";  # Long listing with colors
        iftop = "bandwhich";
        ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
        whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
        k = "kubectl";
        rebuild = "sudo darwin-rebuild switch --flake ~/.nixpkgs";
        update-all = "nix flake update --flake ~/.nixpkgs && sudo darwin-rebuild switch --flake ~/.nixpkgs";
        check-updates = "nix flake update --flake ~/.nixpkgs && nix build --dry-run --no-link ~/.nixpkgs#darwinConfigurations.uber-mac.system 2>&1 | awk '/^these.*derivations will be built:/ { flag=\"build\"; next } /^these.*paths will be fetched:/ { flag=\"fetch\"; next } flag==\"build\" && /^  \\// { gsub(/.*\\//, \"\"); gsub(/\\.drv$/, \"\"); build[NR]=$0; build_count++; next } flag==\"fetch\" && /^  \\// { gsub(/.*\\//, \"\"); fetch[NR]=$0; fetch_count++; next } /MiB download.*MiB unpacked/ { match($0, /\\(([0-9.]+) MiB download, ([0-9.]+) MiB unpacked\\)/, sizes); download=sizes[1]; unpacked=sizes[2]; } END { if (build_count > 0) { print \"\\n=== Packages to Build (\" build_count \") ===\"; for (i in build) print build[i]; } if (fetch_count > 0) { print \"\\n=== Packages to Fetch (\" fetch_count \") ===\"; for (i in fetch) print fetch[i]; } print \"\\n=== Summary ===\"; print \"Total:\", build_count + fetch_count, \"packages (\" build_count, \"to build,\", fetch_count, \"to fetch)\"; if (download) print \"Download:\", download, \"MiB\"; if (unpacked) print \"Unpacked:\", unpacked, \"MiB\"; }'";
        nixgc = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +2 && nix-env -p /nix/var/nix/profiles/per-user/$USER/home-manager --delete-generations +2 && nix-collect-garbage -d";
        python = "python-wrapper";
        python3 = "python3-wrapper";
      };

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
          src = pkgs.fishPlugins.z.src;
        }
        {
          name = "fzf-fish";
          src = pkgs.fishPlugins.fzf-fish.src;
        }
        {
          name = "done";
          src = pkgs.fishPlugins.done.src;
        }
        {
          name = "autopair";
          src = pkgs.fishPlugins.autopair.src;
        }
        {
          name = "plugin-git";
          src = pkgs.fishPlugins.plugin-git.src;
        }
        {
          name = "based";
          src = pkgs.fetchFromGitHub {
            owner = "Edu4rdSHL";
            repo = "based.fish";
            rev = "main";
            sha256 = "sha256-2T4oJPRaMw/iv8pYNq+PJ3iSRoGsbKzSnORCmXU4x5A=";
          };
        }
      ];
    };
  };
}
