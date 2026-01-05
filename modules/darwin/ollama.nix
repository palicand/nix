{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.ollama;
in
{
  options = {
    services.ollama = {
      enable = mkEnableOption "Ollama server for running large language models";

      package = mkOption {
        type = types.package;
        default = pkgs.ollama;
        description = "The Ollama package to use.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "The host address on which the Ollama service listens.";
      };

      port = mkOption {
        type = types.port;
        default = 11434;
        example = 11111;
        description = "Which port the Ollama server listens to.";
      };

      models = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "The directory where Ollama will store and read models.";
      };

      loadModels = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "qwen2.5:7b"
          "deepseek-coder-v2"
        ];
        description = ''
          Download these models using ollama pull as soon as the ollama service has started.
          Search for models at https://ollama.com/library.
        '';
      };

      environmentVariables = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          OLLAMA_DEBUG = "1";
          OLLAMA_KEEP_ALIVE = "24h";
        };
        description = "Set arbitrary environment variables for the Ollama service.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.ollama = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/ollama.out.log";
        StandardErrorPath = "/tmp/ollama.err.log";
        ProgramArguments = [
          "${cfg.package}/bin/ollama"
          "serve"
        ];
        EnvironmentVariables = {
          OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
        }
        // cfg.environmentVariables
        // (optionalAttrs (cfg.models != null) {
          OLLAMA_MODELS = cfg.models;
        });
      };
    };

    # Activation script to manage models after service starts
    system.activationScripts.postActivation.text = mkIf (cfg.loadModels != [ ]) ''
      echo "Managing Ollama models..."

      # Wait for Ollama service to be ready (max 30 seconds)
      attempt=0
      while [ $attempt -lt 30 ]; do
        if ${cfg.package}/bin/ollama list &>/dev/null; then
          break
        fi
        sleep 1
        attempt=$((attempt + 1))
      done

      # Get list of currently installed models
      current_models=$(${cfg.package}/bin/ollama list | tail -n +2 | awk '{print $1}' || echo "")

      # Pull each configured model if not already present
      ${concatMapStringsSep "\n" (model: ''
        if ! ${cfg.package}/bin/ollama list | grep -q "^${model}"; then
          echo "Pulling Ollama model: ${model}"
          ${cfg.package}/bin/ollama pull "${model}" || echo "Warning: Failed to pull ${model}"
        else
          echo "Model ${model} already exists"
        fi
      '') cfg.loadModels}

      # Remove models not in the declarative config
      for model in $current_models; do
        should_keep=false
        ${concatMapStringsSep "\n" (model: ''
          if [ "$model" = "${model}" ]; then
            should_keep=true
          fi
        '') cfg.loadModels}

        if [ "$should_keep" = "false" ] && [ -n "$model" ]; then
          echo "Removing Ollama model not in config: $model"
          ${cfg.package}/bin/ollama rm "$model" || echo "Warning: Failed to remove $model"
        fi
      done
    '';
  };
}
