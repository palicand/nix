{ pkgs, ... }:
{
  # New Mac — Lix installer, nixbld GID 350
  nix.package = pkgs.lix;
  ids.gids.nixbld = 350;

  services.llama-cpp = {
    enable = true;
    models = [
      "ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M"
    ];
  };

  launchd.user.agents.jackett.serviceConfig = {
    ProgramArguments = [
      "${pkgs.jackett}/bin/jackett"
      "--NoRestart"
    ];
    KeepAlive = true;
    RunAtLoad = true;
  };
}
