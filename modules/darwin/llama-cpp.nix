{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    any
    hasPrefix
    mkEnableOption
    mkIf
    mkOption
    types
    unique
    ;

  cfg = config.services.llama-cpp;
  modelSync = pkgs.callPackage ./llama-cpp-model-sync.nix { };
  modelsFile = pkgs.writeText "llama-cpp-models.json" (builtins.toJSON cfg.models);
  syncHost = if cfg.host == "0.0.0.0" then "127.0.0.1" else cfg.host;
  forbiddenExtraArgs = [
    "-m"
    "--model"
    "-hf"
    "-hfr"
    "--hf-repo"
    "--models-dir"
    "--models-preset"
    "--host"
    "--port"
  ];
  extraArgsSelectModelOrEndpoint = any (
    arg: any (forbiddenArg: arg == forbiddenArg || hasPrefix "${forbiddenArg}=" arg) forbiddenExtraArgs
  ) cfg.extraArgs;
in
{
  options.services.llama-cpp = {
    enable = mkEnableOption "llama.cpp router for running large language models";

    package = mkOption {
      type = types.package;
      default = pkgs.llama-cpp;
      description = "The llama.cpp package to use.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "The host address on which llama-server listens.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "The port on which llama-server listens.";
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M" ];
      description = ''
        Hugging Face GGUF model IDs kept in the dedicated llama.cpp cache.
        Missing models are downloaded asynchronously and undeclared models are removed.
      '';
    };

    cacheDir = mkOption {
      type = types.str;
      default = "/Users/${config.system.primaryUser}/Library/Caches/llama.cpp-nix";
      description = "Dedicated cache for declaratively managed llama.cpp models.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Global llama-server arguments that do not select a model or endpoint.";
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional environment variables for llama-server.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models == unique cfg.models;
        message = "services.llama-cpp.models must not contain duplicates";
      }
      {
        assertion = !extraArgsSelectModelOrEndpoint;
        message = ''
          services.llama-cpp.extraArgs must not contain model-source, host, or port arguments
        '';
      }
    ];

    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.llama-cpp.serviceConfig = {
      ProgramArguments = [
        "${cfg.package}/bin/llama-server"
      ]
      ++ cfg.extraArgs
      ++ [
        "--host"
        cfg.host
        "--port"
        (toString cfg.port)
      ];
      EnvironmentVariables = cfg.environmentVariables // {
        LLAMA_CACHE = cfg.cacheDir;
      };
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/llama-cpp.out.log";
      StandardErrorPath = "/tmp/llama-cpp.err.log";
    };

    launchd.user.agents.llama-cpp-model-sync.serviceConfig = {
      ProgramArguments = [ "${modelSync}/bin/llama-cpp-model-sync" ];
      EnvironmentVariables = {
        LLAMA_CPP_BASE_URL = "http://${syncHost}:${toString cfg.port}";
        LLAMA_CPP_MODELS_FILE = "${modelsFile}";
      };
      RunAtLoad = true;
      StartInterval = 900;
      StandardOutPath = "/tmp/llama-cpp-model-sync.out.log";
      StandardErrorPath = "/tmp/llama-cpp-model-sync.err.log";
    };
  };
}
