{
  config,
  lib,
  pkgs,
  ...
}:
{
  homebrew = {

    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";  # Remove packages not in config (zap also removes preferences)
    };
    global = {
      brewfile = true;
      lockfiles = false;
    };
    brews = [
      "gnupg2"
      "pinentry-mac"
    ];

    # Taps are now managed by nix-homebrew in flake.nix
    casks = [
      # Development tools
      "jetbrains-toolbox"
      "lens"
      "postman"
      "gcloud-cli"
      "wireshark-app"
      "zed"

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
      "whatsapp"
      "notion"

      # Media
      "spotify"
      "qbittorrent"
      "vlc"

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
