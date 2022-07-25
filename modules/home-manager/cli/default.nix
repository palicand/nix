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
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "sudo" "common-aliases" ];
      };
      plugins = [{
        name = "gradle-completion";
        src = pkgs.fetchFromGitHub {
          owner = "gradle";
          repo = "gradle-completion";
          rev = "b042038e3d3b30a6440c121268894234c509ca1c";
          sha256 = "sha256-vr2DjRvs46KBZuYyQD/t+mk0vijCqIK5AeGED80sTXI=";
        };
      }];
      initExtra = ''
        if [[ -d /opt/homebrew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
        source <(kubectl completion zsh)
        complete -F __start_kubectl k
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
    skim = {
      enable = true;
    };

    fzf = {
      enable = false;
    };

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
    };

    gitui = {
      enable = true;
    };

  };
}
