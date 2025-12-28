{ config, lib, pkgs, ... }: {
  homebrew = {

    enable = true;
    onActivation.autoUpdate = false;
    onActivation.upgrade = true;
    global = {
      brewfile = true;
      lockfiles = false;
    };
    brews = [
      "gnupg2"
      "pinentry-mac"
    ];

    taps = [
      "homebrew/bundle"
      "homebrew/services"
    ];
    casks = [
      # Development tools
      "jetbrains-toolbox"
      "lens"
      "postman"

      # System utilities
      "stats"
      "alfred"
      "keepassxc"
      "iterm2"
      "itermai"
      "crossover"

      # Security & Privacy
      "mullvad-vpn"
      "1password"

      # Communication
      "signal"
      "slack"

      # Media
      "spotify"
      "qbittorrent"

      # Browsers & Desktop apps
      "firefox"
      "tor-browser"
      "github"

      # Fonts
      "font-iosevka-nerd-font"
    ];
    masApps = { };
  };
}
