{ config, pkgs, ... }:

{
  imports = [ <home-manager/nix-darwin> ];
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  nixpkgs = {
    config.allowUnfree = true;
    config.allowUnsupportedSystem = true;
  };
  # Create /etc/bashrc that loads the nix-darwin environment.
  # programs.zsh.enable = true; # default shell on catalina
  # programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
  };

  homebrew = {
    enable = true;
    autoUpdate = true;
    global = {
      brewfile = true;
      noLock = true;
    };
    brews = [
      "gnupg2"
      "pinentry-mac"
    ];

    taps = [
      "homebrew/bundle"
      "homebrew/cask"
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/core"
      "homebrew/services"
    ];
    casks = [
      "gpg-suite"
      "jetbrains-toolbox"
      "stats"
      "visual-studio-code"
      "firefox"
      "keepassxc"
      "font-iosevka-nerd-font"
      "spotify"
      "mullvadvpn"
      "iterm2"
      "kitty"
    ];
  };

  users.users.palicand = {
    name = "palicand";
    home = "/Users/palicand";
  };

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
    rnix-lsp
  ];

  home-manager.users.palicand = { pkgs, ... }: {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.allowUnsupportedSystem = true;

    home.packages = with pkgs; [
      wget
      tmux
      yadm
      fzf
      yarn
      rustup
      poetry
      ripgrep
      bat
      bandwhich
      google-cloud-sdk
      postgresql
      jq
      openssh
      rsync
      tree
      yq
      pgcli
      jdk17_headless
      kubernetes
      kubernetes-helm
      cachix
      man-db
      git
    ];
    programs.zsh = {
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
      initExtra = ''
        if [[ -d /opt/homebrew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
      '';
      shellAliases = {
        grep = "rg";
        cat = "bat";
        iftop = "bandwhich";
        ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
        whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
      };
    };
    programs = {
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
    };

    # Use a custom configuration.nix location.
    # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
    # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";


  };

}
