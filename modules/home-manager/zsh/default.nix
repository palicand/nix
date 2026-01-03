{ config, pkgs, ... }:
{
  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "$HOME/.antigravity/antigravity/bin"
    "/opt/homebrew/share/google-cloud-sdk/bin"
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
        plugins = [ "git" "sudo" "common-aliases" "yarn" "docker" "npm" "dotenv" ];
      };
      initContent = ''
        # Homebrew shell environment (macOS)
        if [[ -d /opt/homebrew ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        # GPG agent for SSH
        export GPG_TTY=$(tty)
        export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

        # Kubectl completion
        source <(kubectl completion zsh)
        complete -F __start_kubectl k

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
      '';
      shellAliases = {
        grep = "rg";
        cat = "bat";
        cp = "cp --reflink=auto";  # Use copy-on-write (CoW) when possible
        ls = "ls --color=auto";  # Enable colors for GNU ls
        ll = "ls -lah --color=auto";  # Long listing with colors
        iftop = "bandwhich";
        ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
        whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
        k = "kubectl";
        rebuild = "sudo darwin-rebuild switch --flake ~/.nixpkgs";
        update-all = "nix flake update --flake ~/.nixpkgs && sudo darwin-rebuild switch --flake ~/.nixpkgs";
        nixgc = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +2 && nix-env -p /nix/var/nix/profiles/per-user/$USER/home-manager --delete-generations +2 && nix-collect-garbage -d";
        python = "python-wrapper";
        python3 = "python3-wrapper";
      };
    };

    starship = {
      enable = true;
      package = pkgs.starship;
      # To use a preset, run: starship preset <name> -o ~/.config/starship.toml
      # Available presets: bracketed-segments, gruvbox-rainbow, jetpack, nerd-font-symbols,
      #                    no-runtime-versions, pastel-powerline, plain-text-symbols, pure-preset, tokyo-night
      settings = {
        # Custom format - put kubernetes at the end, input on new line
        format = "$directory$git_branch$git_status$kubernetes\n$character";

        # Disable GCP account display
        gcloud.disabled = true;

        # Always show Kubernetes context in bright blue (at the end)
        kubernetes = {
          disabled = false;
          format = "on [󱃾 $context \\($namespace\\)](bright-blue) ";
          symbol = "󱃾 ";
        };

        # Show current directory everywhere (not just in git repos)
        directory = {
          disabled = false;
          truncation_length = 3;
          truncate_to_repo = false;
          read_only = " 󰌾";
        };

        # Show git status
        git_branch = {
          disabled = false;
        };

        git_status = {
          disabled = false;
        };
      };
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
    };

    gitui = {
      enable = false;
    };

  };
}
