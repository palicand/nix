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

      # Security & Privacy
      "mullvad-vpn"
      "1password"

      # Communication
      "signal"
      "slack"

      # Media
      "spotify"

      # Browsers & Desktop apps
      "firefox"
      "github"

      # Fonts
      "font-iosevka-nerd-font"
    ];
    masApps = { };
  };
}
