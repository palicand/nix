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
      "visualvm"
      "wireshark-app"
      "zed"

      # System utilities
      "orbstack"
      "utm"
      "crystalfetch"
      "stats"
      "alfred"
      "cmux"
      "ghostty"
      "crossover"
      "wispr-flow"

      # Security & Privacy
      "mullvad-vpn"
      "keepassxc"

      # Communication
      "signal"
      "slack"
      "telegram"
      "whatsapp"
      "notion"

      # Knowledge management
      "obsidian"

      # Productivity (includes OneDrive)
      "microsoft-office"

      # Design & CAD
      "autodesk-fusion"

      # Media
      "spotify"
      "qbittorrent"
      "radarr"
      "sonarr"
      "prowlarr"
      "vlc"
      "netnewswire"

      # Gaming
      "steam"

      # AI
      "claude"

      # Browsers & Desktop apps
      "google-chrome"
      "firefox"
      "tor-browser"
      "github"

      # Fonts
      "font-iosevka-nerd-font"
    ];
    masApps = { };
  };
}
