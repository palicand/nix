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
      # Homebrew 6.0 dropped `brew bundle --force-cleanup`, which nix-darwin still emits for "zap"/"uninstall" (aborting activation). Keep "none" until nix-darwin supports the 6.0 bundle CLI; prune manually with `brew bundle cleanup --file=<Brewfile>`.
      cleanup = "none";
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
      "gitkraken"
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
