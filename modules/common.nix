{ inputs, config, lib, pkgs, ... }: {
  imports = [ ./primary.nix ./nixpkgs.nix ];

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
    };
  };

  user = {
    description = "Andrej Palicka";
    home = "${
        if pkgs.stdenvNoCC.isDarwin then "/Users" else "/home"
      }/${config.user.name}";
    shell = pkgs.zsh;
  };

  # bootstrap home manager using system config
  hm = import ./home-manager;

  # let nix manage home-manager profiles and use global nixpkgs
  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
  };

  # environment setup
  environment = {
    systemPackages = with pkgs; [
      # editors
      neovim

      # standard toolset
      coreutils-full
      curl
      wget
      git
      jq

      # helpful shell stuff
      bat
      fzf
      # ripgrep

      # languages
      (python3.withPackages (ps: with ps; with python3Packages; [
        ipython
        asyncpg
        # Uncomment the following lines to make them available in the shell.
        # pandas
        # numpy
        # matplotlib
      ]))
      ruby
      rustup
    ];
    etc = {
      home-manager.source = "${inputs.home-manager}";
      nixpkgs.source = "${pkgs.path}";
      stable.source = "${inputs.stable}";
    };
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash zsh fish ];
  };


  fonts.fonts = with pkgs; [ jetbrains-mono ];
}
