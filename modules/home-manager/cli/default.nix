{ config, pkgs, ... }:
{
  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
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

        # Git worktree wrapper - creates worktree and cds into it
        # Usage: gwt <dir-suffix> <branch-name>
        # Example: gwt feature-123 feat/my-feature
        # Unalias gwt if oh-my-zsh git plugin created it
        unalias gwt 2>/dev/null || true
        gwt() {
          if [[ $# -ne 2 ]]; then
            echo "Usage: gwt <dir-suffix> <branch-name>"
            echo "Example: gwt feature-123 feat/my-feature"
            return 1
          fi

          local worktree_dir=$(git wt "$1" "$2" | tail -n 1)
          if [[ -d "$worktree_dir" ]]; then
            cd "$worktree_dir"
          fi
        }
      '';
      shellAliases = {
        grep = "rg";
        cat = "bat";
        iftop = "bandwhich";
        ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
        whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
        k = "kubectl";
        rebuild = "darwin-rebuild switch --flake ~/.nixpkgs";
      };
    };

    starship = {
      enable = true;
      package = pkgs.starship;
      # To use a preset, run: starship preset <name> -o ~/.config/starship.toml
      # Available presets: bracketed-segments, gruvbox-rainbow, jetpack, nerd-font-symbols,
      #                    no-runtime-versions, pastel-powerline, plain-text-symbols, pure-preset, tokyo-night
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
