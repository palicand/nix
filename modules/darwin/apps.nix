{ config, lib, pkgs, ... }: {
  homebrew = {

    enable = true;
    onActivation.autoUpdate = false;
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
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/services"
    ];
    casks = [
      "jetbrains-toolbox"
      "stats"
      "visual-studio-code"
      "firefox"
      "keepassxc"
      "font-iosevka-nerd-font"
      "spotify"
      "mullvad-vpn"
      "iterm2"
      "kitty"
      "alfred"
      "postman"
      "signal"
      "1password"
      "slack"
      "notion"
      "github"
    ];
    masApps = { };
  };
}
