{ lib, pkgs }:

let
  evalService =
    serviceConfig:
    lib.evalModules {
      modules = [
        ../modules/darwin/llama-cpp.nix
        (
          { lib, ... }:
          {
            options = {
              assertions = lib.mkOption {
                type = lib.types.listOf lib.types.anything;
                default = [ ];
              };
              environment.systemPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
              launchd.user.agents = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
              system.primaryUser = lib.mkOption {
                type = lib.types.str;
                default = "tester";
              };
            };

            config.services.llama-cpp = {
              enable = true;
              package = pkgs.llama-cpp;
            }
            // serviceConfig;
          }
        )
      ];
      specialArgs = { inherit pkgs; };
    };

  assertionsPass =
    serviceConfig:
    builtins.all (assertion: assertion.assertion) (evalService serviceConfig).config.assertions;
  syncUrl =
    host:
    (evalService { inherit host; })
    .config.launchd.user.agents.llama-cpp-model-sync.serviceConfig.EnvironmentVariables.LLAMA_CPP_BASE_URL;

  forbiddenArgs = [
    "-m"
    "--model=/tmp/model.gguf"
    "-mu"
    "--model-url=https://example.invalid/model.gguf"
    "-dr"
    "--docker-repo=ai/model:latest"
    "-hf"
    "-hfr"
    "--hf-repo=org/model:Q4_K_M"
    "-hff"
    "--hf-file=model-Q4_K_M.gguf"
    "--models-dir=/tmp/models"
    "--models-preset=/tmp/models.ini"
    "--host=localhost"
    "--port=9000"
  ];
  forbiddenEnvironmentVariables = [
    "LLAMA_ARG_MODEL"
    "LLAMA_ARG_MODEL_URL"
    "LLAMA_ARG_DOCKER_REPO"
    "LLAMA_ARG_HF_REPO"
    "LLAMA_ARG_HF_FILE"
    "LLAMA_ARG_MODELS_DIR"
    "LLAMA_ARG_MODELS_PRESET"
    "LLAMA_ARG_HOST"
    "LLAMA_ARG_PORT"
  ];
in
assert builtins.all (arg: !assertionsPass { extraArgs = [ arg ]; }) forbiddenArgs;
assert builtins.all (
  name: !assertionsPass { environmentVariables.${name} = "override"; }
) forbiddenEnvironmentVariables;
assert assertionsPass {
  extraArgs = [
    "--ctx-size"
    "32768"
  ];
  environmentVariables.LLAMA_ARG_N_GPU_LAYERS = "all";
};
assert !assertionsPass { models = [ "" ]; };
assert !assertionsPass { models = [ "org/model:Q4\nsecond/model:Q4" ]; };
assert !assertionsPass { models = [ "org/model:Q4\rsecond/model:Q4" ]; };
assert syncUrl "127.0.0.1" == "http://127.0.0.1:8080";
assert syncUrl "0.0.0.0" == "http://127.0.0.1:8080";
assert syncUrl "::1" == "http://[::1]:8080";
assert syncUrl "::" == "http://[::1]:8080";
assert syncUrl "0:0:0:0:0:0:0:0" == "http://[::1]:8080";
pkgs.runCommand "llama-cpp-module-test" { } ''
  touch "$out"
''
