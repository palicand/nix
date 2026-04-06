{ pkgs, ... }:
{
  # New Mac — Lix installer, nixbld GID 350
  nix.package = pkgs.lix;
  ids.gids.nixbld = 350;

  services.ollama.enable = true;
}
