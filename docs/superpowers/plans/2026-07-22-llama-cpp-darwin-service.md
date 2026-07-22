# Declarative llama.cpp Darwin Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom Ollama nix-darwin service with a toggleable llama.cpp router whose Hugging Face GGUF model cache is reconciled from Nix in the background.

**Architecture:** A focused shell application reconciles desired model IDs through llama-server's router API and is independently integration-tested against a fake HTTP server. A nix-darwin module owns the llama.cpp package, persistent server launchd job, scheduled synchronization job, isolated cache, and host-facing options.

**Tech Stack:** Nix, nix-darwin, launchd, llama.cpp `llama-server`, Bash, curl, jq, Python standard-library HTTP test server.

## Global Constraints

- Use `services.llama-cpp.enable` as the single service flag.
- Default to `pkgs.llama-cpp`, `127.0.0.1`, and port `8080`.
- Declare `ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M` on `mac-2026`.
- Run llama-server without `-m` or `-hf`, preserving multi-model router mode.
- Download models asynchronously; no Nix evaluation, check, build, or activation may download a model.
- Delete undeclared models only through the router attached to the dedicated Nix-managed cache.
- Retry reconciliation every 15 minutes without a tight launchd restart loop.
- Disabling the module removes the package and launchd jobs but preserves downloaded llama.cpp data.
- Remove Ollama from active Nix sources without deleting historical Ollama data from the user's home directory.
- Prefix every shell command with `rtk`, per `/Users/palicand/.codex/RTK.md`.

## File Structure

- Create `modules/darwin/llama-cpp-model-sync.sh`: API reconciliation logic with environment-variable inputs and no Nix knowledge.
- Create `modules/darwin/llama-cpp-model-sync.nix`: package the synchronizer with store-pinned curl and jq.
- Create `tests/llama-cpp-model-sync.py`: exercise additions, removals, idempotency, and server timeout through real local HTTP requests.
- Create `modules/darwin/llama-cpp.nix`: define service options and both launchd jobs.
- Modify `modules/darwin/default.nix`: import the llama.cpp module instead of Ollama.
- Modify `hosts/mac-2026.nix`: enable llama.cpp and declare the Qwen GGUF model.
- Modify `flake.nix`: expose the synchronizer integration test and the `mac-2026` system build as flake checks.
- Delete `modules/darwin/ollama.nix`: remove the obsolete module rather than retaining a compatibility alias.

---

### Task 1: Model Reconciliation Application

**Files:**
- Create: `modules/darwin/llama-cpp-model-sync.sh`
- Create: `modules/darwin/llama-cpp-model-sync.nix`
- Create: `tests/llama-cpp-model-sync.py`
- Modify: `flake.nix`

**Interfaces:**
- Consumes: llama-server router endpoints `GET /models?reload=1`, `POST /models`, `POST /models/unload`, and `DELETE /models?model=...`.
- Consumes: `LLAMA_CPP_BASE_URL`, `LLAMA_CPP_MODELS_FILE`, `LLAMA_CPP_MAX_ATTEMPTS`, and `LLAMA_CPP_RETRY_DELAY` environment variables.
- Produces: `${modelSync}/bin/llama-cpp-model-sync`, later referenced by the nix-darwin module.
- Produces: `checks.<darwin-system>.llama-cpp-model-sync`, later used by the final acceptance gate.

- [ ] **Step 1: Write the failing HTTP integration test**

Create `tests/llama-cpp-model-sync.py`:

```python
#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


class RouterHandler(BaseHTTPRequestHandler):
    models = {"keep/model:Q4", "old/model:Q4"}
    mutations = []

    def log_message(self, _format, *_args):
        pass

    def send_json(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_model(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length) or b"{}")
        return payload["model"]

    def do_GET(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/models":
            self.send_json(404, {"error": "not found"})
            return
        self.send_json(
            200,
            {"data": [{"id": model} for model in sorted(self.models)]},
        )

    def do_POST(self):
        model = self.read_model()
        if self.path == "/models/unload":
            self.mutations.append(("POST", self.path, model))
            self.send_json(200, {"success": True})
            return
        if self.path == "/models":
            self.mutations.append(("POST", self.path, model))
            self.models.add(model)
            self.send_json(200, {"success": True})
            return
        self.send_json(404, {"error": "not found"})

    def do_DELETE(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/models":
            self.send_json(404, {"error": "not found"})
            return
        model = parse_qs(parsed.query)["model"][0]
        self.mutations.append(("DELETE", parsed.path, model))
        self.models.discard(model)
        self.send_json(200, {"success": True})


def run_sync(binary, base_url, models_file):
    env = os.environ.copy()
    env.update(
        {
            "LLAMA_CPP_BASE_URL": base_url,
            "LLAMA_CPP_MODELS_FILE": models_file,
            "LLAMA_CPP_MAX_ATTEMPTS": "2",
            "LLAMA_CPP_RETRY_DELAY": "0",
        }
    )
    return subprocess.run(
        [binary],
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    sync_binary = sys.argv[1]
    server = ThreadingHTTPServer(("127.0.0.1", 0), RouterHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f"http://127.0.0.1:{server.server_port}"

    with tempfile.TemporaryDirectory() as temp_dir:
        models_file = os.path.join(temp_dir, "models.json")
        with open(models_file, "w", encoding="utf-8") as handle:
            json.dump(["keep/model:Q4", "new/model:Q4"], handle)

        first = run_sync(sync_binary, base_url, models_file)
        require(first.returncode == 0, first.stderr)
        require(
            RouterHandler.mutations
            == [
                ("POST", "/models/unload", "old/model:Q4"),
                ("DELETE", "/models", "old/model:Q4"),
                ("POST", "/models", "new/model:Q4"),
            ],
            f"unexpected mutations: {RouterHandler.mutations}",
        )
        require(
            RouterHandler.models == {"keep/model:Q4", "new/model:Q4"},
            f"unexpected model set: {RouterHandler.models}",
        )

        RouterHandler.mutations.clear()
        second = run_sync(sync_binary, base_url, models_file)
        require(second.returncode == 0, second.stderr)
        require(
            RouterHandler.mutations == [],
            f"second run was not idempotent: {RouterHandler.mutations}",
        )

        server.shutdown()
        server.server_close()
        thread.join()
        unreachable = run_sync(sync_binary, base_url, models_file)
        require(unreachable.returncode != 0, "unreachable server unexpectedly passed")
        require(
            "not ready after 2 attempts" in unreachable.stderr,
            f"missing timeout diagnostic: {unreachable.stderr}",
        )

    print("llama-cpp model sync tests passed")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the test to verify it fails because the executable does not exist**

Run:

```bash
rtk python3 tests/llama-cpp-model-sync.py /tmp/does-not-exist
```

Expected: FAIL with `FileNotFoundError: [Errno 2] No such file or directory: '/tmp/does-not-exist'`.

- [ ] **Step 3: Implement the minimal reconciliation script**

Create `modules/darwin/llama-cpp-model-sync.sh`:

```bash
set -euo pipefail

base_url="${LLAMA_CPP_BASE_URL:-http://127.0.0.1:8080}"
models_file="${LLAMA_CPP_MODELS_FILE:?LLAMA_CPP_MODELS_FILE must point to desired-model JSON}"
max_attempts="${LLAMA_CPP_MAX_ATTEMPTS:-60}"
retry_delay="${LLAMA_CPP_RETRY_DELAY:-1}"
curl_bin="${LLAMA_CPP_CURL:-curl}"

attempt=1
while ! inventory="$("$curl_bin" --fail --silent --show-error "$base_url/models?reload=1")"; do
  if (( attempt >= max_attempts )); then
    echo "llama-server is not ready after $max_attempts attempts" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep "$retry_delay"
done

is_desired() {
  jq --exit-status --arg model "$1" 'index($model) != null' "$models_file" >/dev/null
}

is_current() {
  jq --exit-status --arg model "$1" \
    '[.data[]?.id] | index($model) != null' <<<"$inventory" >/dev/null
}

while IFS= read -r model; do
  if is_desired "$model"; then
    continue
  fi

  echo "Removing undeclared llama.cpp model: $model"
  payload="$(jq --null-input --compact-output --arg model "$model" '{model: $model}')"
  "$curl_bin" --fail --silent --show-error \
    --request POST \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$base_url/models/unload" >/dev/null || true
  "$curl_bin" --fail --silent --show-error \
    --request DELETE \
    --get \
    --data-urlencode "model=$model" \
    "$base_url/models" >/dev/null
done < <(jq --raw-output '.data[]?.id' <<<"$inventory")

while IFS= read -r model; do
  if is_current "$model"; then
    continue
  fi

  echo "Requesting llama.cpp model download: $model"
  payload="$(jq --null-input --compact-output --arg model "$model" '{model: $model}')"
  "$curl_bin" --fail --silent --show-error \
    --request POST \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$base_url/models" >/dev/null
done < <(jq --raw-output '.[]' "$models_file")
```

Create `modules/darwin/llama-cpp-model-sync.nix`:

```nix
{
  curl,
  jq,
  writeShellApplication,
}:

writeShellApplication {
  name = "llama-cpp-model-sync";
  runtimeInputs = [
    curl
    jq
  ];
  text = builtins.readFile ./llama-cpp-model-sync.sh;
}
```

- [ ] **Step 4: Expose the integration test as a flake check**

In `flake.nix`, add this helper next to `mkDarwinConfig` in the top-level `let`:

```nix
      mkLlamaCppModelSyncCheck =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          modelSync = pkgs.callPackage ./modules/darwin/llama-cpp-model-sync.nix { };
        in
        pkgs.runCommand "llama-cpp-model-sync-test" { } ''
          ${pkgs.python3}/bin/python \
            ${./tests/llama-cpp-model-sync.py} \
            ${modelSync}/bin/llama-cpp-model-sync
          touch "$out"
        '';
```

Change each Darwin check value from:

```nix
          value = {
            darwin = self.darwinConfigurations.uber-mac.config.system.build.toplevel;
          };
```

to:

```nix
          value = {
            darwin = self.darwinConfigurations.uber-mac.config.system.build.toplevel;
            llama-cpp-model-sync = mkLlamaCppModelSyncCheck system;
          };
```

- [ ] **Step 5: Run the focused check and confirm all reconciliation behaviors pass**

Run:

```bash
rtk nix build 'path:.#checks.aarch64-darwin.llama-cpp-model-sync' --no-link
```

Expected: PASS, with the Python test printing `llama-cpp model sync tests passed` in the derivation log if rebuilt with `-L`. The test must finish without downloading a Hugging Face model.

- [ ] **Step 6: Commit the standalone synchronizer**

Use the `commit` skill to review and commit only these files:

```bash
rtk git add flake.nix \
  modules/darwin/llama-cpp-model-sync.nix \
  modules/darwin/llama-cpp-model-sync.sh \
  tests/llama-cpp-model-sync.py
rtk git diff --cached --check
rtk git commit -m "feat(llama-cpp): Add model reconciliation"
```

Expected: one commit containing the tested, service-independent reconciliation component.

---

### Task 2: nix-darwin Service and Ollama Migration

**Files:**
- Create: `modules/darwin/llama-cpp.nix`
- Modify: `modules/darwin/default.nix`
- Modify: `hosts/mac-2026.nix`
- Modify: `flake.nix`
- Delete: `modules/darwin/ollama.nix`

**Interfaces:**
- Consumes: `${modelSync}/bin/llama-cpp-model-sync` from Task 1.
- Produces: `services.llama-cpp.{enable,package,host,port,models,cacheDir,extraArgs,environmentVariables}`.
- Produces: `launchd.user.agents.llama-cpp` and `launchd.user.agents.llama-cpp-model-sync` when enabled.
- Produces: `checks.aarch64-darwin.mac-2026`, the complete host system closure.

- [ ] **Step 1: Wire the desired configuration before the module exists**

Apply these changes as the failing configuration-level test:

```diff
diff --git a/modules/darwin/default.nix b/modules/darwin/default.nix
@@
-    ./ollama.nix
+    ./llama-cpp.nix
diff --git a/hosts/mac-2026.nix b/hosts/mac-2026.nix
@@
-  services.ollama.enable = true;
+  services.llama-cpp = {
+    enable = true;
+    models = [
+      "ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M"
+    ];
+  };
```

Delete `modules/darwin/ollama.nix` with `apply_patch`; do not delete `~/.ollama` or any user data.

- [ ] **Step 2: Run evaluation and confirm it fails on the missing module**

Run:

```bash
rtk nix eval --json 'path:.#darwinConfigurations.mac-2026.config.services.llama-cpp.models'
```

Expected: FAIL because `modules/darwin/llama-cpp.nix` does not exist yet. This demonstrates that the host migration is not accidentally satisfied by another module or compatibility alias.

- [ ] **Step 3: Implement the nix-darwin module**

Create `modules/darwin/llama-cpp.nix`:

```nix
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
    arg:
    any (
      forbiddenArg: arg == forbiddenArg || hasPrefix "${forbiddenArg}=" arg
    ) forbiddenExtraArgs
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
      ProgramArguments = [ "${cfg.package}/bin/llama-server" ] ++ cfg.extraArgs ++ [
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
        LLAMA_CPP_MODELS_FILE = modelsFile;
      };
      RunAtLoad = true;
      StartInterval = 900;
      StandardOutPath = "/tmp/llama-cpp-model-sync.out.log";
      StandardErrorPath = "/tmp/llama-cpp-model-sync.err.log";
    };
  };
}
```

- [ ] **Step 4: Evaluate the public interface and generated launchd jobs**

Run:

```bash
rtk nix eval --json 'path:.#darwinConfigurations.mac-2026.config.services.llama-cpp.models'
rtk nix eval --json 'path:.#darwinConfigurations.mac-2026.config.launchd.user.agents.llama-cpp.serviceConfig.ProgramArguments'
rtk nix eval --json 'path:.#darwinConfigurations.mac-2026.config.launchd.user.agents.llama-cpp-model-sync.serviceConfig'
rtk nix eval --raw 'path:.#darwinConfigurations.mac-2026.config.services.llama-cpp.package.pname'
rtk nix eval --json 'path:.#darwinConfigurations.uber-mac.config.services.llama-cpp.enable'
```

Expected results:

- Models evaluate to `["ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M"]`.
- Server arguments start with a store path ending in `/bin/llama-server` and end with `--host`, `127.0.0.1`, `--port`, `8080`; they contain no `-m` or `-hf`.
- Sync configuration has `RunAtLoad = true`, `StartInterval = 900`, base URL `http://127.0.0.1:8080`, and a store-backed desired-model JSON path.
- Package pname is `llama-cpp`.
- `uber-mac` reports `false`, proving the service is toggleable and disabled by default.

- [ ] **Step 5: Add the complete host build to flake checks**

In `flake.nix`, change the Darwin check value created in Task 1 to:

```nix
          value =
            {
              darwin = self.darwinConfigurations.uber-mac.config.system.build.toplevel;
              llama-cpp-model-sync = mkLlamaCppModelSyncCheck system;
            }
            // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
              mac-2026 = self.darwinConfigurations.mac-2026.config.system.build.toplevel;
            };
```

The `optionalAttrs` guard prevents an aarch64-only host build from being exposed as an x86_64 check.

- [ ] **Step 6: Format and run the complete acceptance gate**

Run:

```bash
rtk nix fmt -- flake.nix hosts/mac-2026.nix modules/darwin/default.nix modules/darwin/llama-cpp.nix modules/darwin/llama-cpp-model-sync.nix
rtk nix flake check 'path:.' --no-build
rtk nix build 'path:.#checks.aarch64-darwin.llama-cpp-model-sync' --no-link
rtk nix build 'path:.#checks.aarch64-darwin.mac-2026' --no-link
! rtk rg -n -i 'ollama' . --glob '*.nix'
rtk git diff --check
```

Expected:

- Formatting completes without introducing unrelated changes.
- Flake evaluation passes.
- Both focused synchronizer and complete `mac-2026` checks build successfully.
- The model is not downloaded during any command.
- The Ollama search produces no matches and succeeds because it is negated.
- Git reports no whitespace errors.

- [ ] **Step 7: Commit the Darwin migration**

Use the `commit` skill to review all task changes, confirm there are no unrelated files, and commit:

```bash
rtk git add flake.nix \
  hosts/mac-2026.nix \
  modules/darwin/default.nix \
  modules/darwin/llama-cpp.nix \
  modules/darwin/ollama.nix
rtk git diff --cached --check
rtk git commit -m "feat(darwin): Replace Ollama with llama.cpp"
```

Expected: one feature commit that removes the Ollama module, enables the llama.cpp router on `mac-2026`, and preserves the already-tested synchronizer commit.

---

## Final Runtime Handoff

Do not run `darwin-rebuild switch` without explicit user authorization because it mutates the live machine and starts a large background download. Report the verified code result and provide these post-activation checks:

```bash
rtk curl http://127.0.0.1:8080/health
rtk curl http://127.0.0.1:8080/models
rtk curl http://127.0.0.1:8080/v1/models
rtk proxy tail -f /tmp/llama-cpp-model-sync.out.log /tmp/llama-cpp-model-sync.err.log
```

Expected after activation: the router becomes healthy, the declared Qwen model transitions through downloading to available, and the OpenAI-compatible endpoint reports it without blocking the rebuild itself.
