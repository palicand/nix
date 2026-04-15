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
      "stats"
      "alfred"
      "keepassxc"
      "cmux"
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

      # Knowledge management
      "obsidian"

      # Cloud storage
      "onedrive"

      # Design & CAD
      "autodesk-fusion"

      # Media
      "spotify"
      "qbittorrent"
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
