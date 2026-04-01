{ pkgs, ... }:
{
  # Old Mac — standard Nix, nixbld GID 30000 (pre-2024 installer)
  nix.package = pkgs.nix;
  ids.gids.nixbld = 30000;
}
