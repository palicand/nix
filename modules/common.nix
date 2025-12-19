{ inputs, config, lib, pkgs, ... }: {
  imports = [ ./primary.nix ./nixpkgs.nix ];

  user = {
    description = "Andrej Palicka";
    home = "${
        if pkgs.stdenvNoCC.isDarwin then "/Users" else "/home"
      }/${config.user.name}";
    shell = pkgs.fish;
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
      # Essential system utilities only
      coreutils-full
      curl
      wget
      git
    ];
    etc = {
      home-manager.source = "${inputs.home-manager}";
      nixpkgs.source = "${pkgs.path}";
    };
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash zsh fish ];
  };

}
