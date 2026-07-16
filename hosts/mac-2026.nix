{ pkgs, ... }:
{
  # New Mac — Lix installer, nixbld GID 350
  nix.package = pkgs.lix;
  ids.gids.nixbld = 350;

  services.ollama.enable = true;

  launchd.user.agents.jackett.serviceConfig = {
    ProgramArguments = [
      "${pkgs.jackett}/bin/jackett"
      "--NoRestart"
    ];
    KeepAlive = true;
    RunAtLoad = true;
  };
}
