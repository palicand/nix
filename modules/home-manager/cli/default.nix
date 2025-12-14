{ config, pkgs, ... }:
{
  programs = {
    zsh = {
      localVariables = {
        LANG = "en_US.UTF-8";
        GPG_TTY = "/dev/ttys000";
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
        if [[ -d /opt/homebrew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
        source <(kubectl completion zsh)
        complete -F __start_kubectl k

        export PATH=/etc/profiles/per-user/palicand/bin:~/.npm-global/bin:~/.cargo/bin:$PATH
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
    };

    fzf = {
      enable = true;
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
