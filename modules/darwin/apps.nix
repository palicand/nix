{ config, lib, pkgs, ... }: {
  homebrew = {
    
    enable = true;
    autoUpdate = false;
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
      "alfred"
    ];
    masApps = { };
  };
}
