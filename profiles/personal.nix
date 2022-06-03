{ config, lib, pkgs, ... }: {
  user.name = "palicand";
  hm = { imports = [ ./home-manager/personal.nix ]; };
}
