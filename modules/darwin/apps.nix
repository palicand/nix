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
      cleanup = "zap"; # Remove packages not in config (zap also removes preferences)
    };
    global = {
      brewfile = true;
      lockfiles = false;
    };
    brews = [
      "gnupg2"
      "pinentry-mac"
      "cloud-sql-proxy"
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
      "ghostty"
      "iterm2"
      "itermai"
      "crossover"
      "wispr-flow"

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

      # AI
      "claude"

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
