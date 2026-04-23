{ config, pkgs, ... }:

{
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    allowUnsupportedSystem = true;
  };

  # Workaround: direnv 2.37.1 in nixpkgs uses -linkmode=external but sets CGO_ENABLED=0
  nixpkgs.overlays = [
    (final: prev: {
      direnv = prev.direnv.overrideAttrs (old: {
        env = (old.env or { }) // {
          CGO_ENABLED = 1;
        };
      });
      lix = prev.lix.overrideAttrs (old: {
        doInstallCheck = false;
      });
    })
  ];
  imports = [
    ../common.nix
    ./ollama.nix
    ./charging-chime.nix
    ./filevault.nix
  ];
  # Auto upgrade nix package and the daemon service.
  # Create /etc/bashrc that loads the nix-darwin environment.
  # programs.zsh.enable = true; # default shell on catalina
  programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system = {
    stateVersion = 6;
    primaryUser = "palicand";
    # Disable charging chime/alert sound
    chargingChime.enable = false;
    # Assert FileVault stays enabled on every rebuild
    fileVault.enable = true;
  };

  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
    enableSyntaxHighlighting = true;
  };

  users.users.palicand = {
    name = "palicand";
    home = "/Users/palicand";
  };

  # Enable passwordless sudo
  security.sudo.extraConfig = ''
    palicand ALL = (ALL) NOPASSWD: ALL
  '';

  # Install Iosevka Nerd Font
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  environment = {
    pathsToLink = [ "/lib" ];

    systemPackages = with pkgs; [
      nixpkgs-fmt
    ];

    # Make Nix-managed binaries visible to GUI apps via macOS path_helper
    etc."paths.d/nix".text = ''
      /etc/profiles/per-user/${config.user.name}/bin
      /run/current-system/sw/bin
      /nix/var/nix/profiles/default/bin
      /opt/homebrew/bin
      /opt/homebrew/share/google-cloud-sdk/bin
    '';
  };

  # Set PATH for GUI apps (Finder/Dock/Spotlight) that don't use path_helper
  launchd.user.envVariables.PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/share/google-cloud-sdk/bin:${config.environment.systemPath}";
  # Upstream bug in nixpkgs' split nodejs: npm's default globalPrefix
  # resolves inside the `nodejs-slim` store output (which has no `lib/`),
  # so any `npx` launch without an existing .npmrc fails with
  # `ENOENT: lstat '…-nodejs-slim-20.20.2/lib'`. Pinning a user-owned prefix
  # sidesteps the default. Launchd doesn't expand $HOME, so use the
  # absolute path. Mirrored in home-manager/default.nix for shells.
  launchd.user.envVariables.NPM_CONFIG_PREFIX = "/Users/palicand/.npm-global";
}
