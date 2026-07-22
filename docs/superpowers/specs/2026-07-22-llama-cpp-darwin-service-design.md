# Declarative llama.cpp Darwin Service

Replace the custom Ollama nix-darwin integration with a llama.cpp server that
retains the useful Nix behavior: one enable flag, a declarative model list,
background service management, asynchronous model downloads, and removal of
models no longer declared.

## Scope

The change applies to the custom Darwin service module and the `mac-2026` host.
It removes every Ollama package, option, import, launchd job, and configuration
reference from the active Nix sources. It does not delete historical Ollama
data from the user's home directory.

The initial model is the llama.cpp-compatible GGUF checkpoint:

```text
ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M
```

The NVIDIA `nvidia/Qwen3.6-35B-A3B-NVFP4` checkpoint is deliberately excluded.
It is a ModelOpt Safetensors checkpoint for vLLM on NVIDIA Hopper or Blackwell,
not a GGUF checkpoint that llama.cpp can serve through Metal.

## Module Interface

Create `modules/darwin/llama-cpp.nix`, import it from
`modules/darwin/default.nix`, and delete `modules/darwin/ollama.nix`.

The normal host configuration is:

```nix
services.llama-cpp = {
  enable = true;
  models = [
    "ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M"
  ];
};
```

The module exposes these options:

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | boolean | `false` | Install and run the service and synchronizer. |
| `package` | package | `pkgs.llama-cpp` | Select the llama.cpp build. |
| `host` | string | `127.0.0.1` | Bind address for the HTTP server. |
| `port` | port | `8080` | Standard llama.cpp server port. |
| `models` | list of strings | `[]` | Desired Hugging Face GGUF model IDs, including an optional quantization tag. |
| `cacheDir` | string | a dedicated cache under the primary user's `Library/Caches` | Isolate Nix-managed model files from other Hugging Face consumers. |
| `extraArgs` | list of strings | `[]` | Add global llama-server runtime tuning. |
| `environmentVariables` | string attribute set | `{}` | Add advanced server environment variables. |

Required router arguments, including host and port, are emitted by the module.
`extraArgs` is for inference tuning and must not select a single model or change
the router's model source.

When disabled, the module contributes no package and no launchd jobs. Disabling
the service preserves the llama.cpp cache, as service-disable operations do not
normally destroy user data.

## Runtime Architecture

Enabling the module adds `cfg.package` to `environment.systemPackages` and
defines two user launchd jobs.

### Server job

`llama-cpp` runs `${cfg.package}/bin/llama-server` without `-m` or `-hf`, which
selects llama.cpp's multi-model router mode. It supplies `--host`, `--port`, and
the configured global arguments. `LLAMA_CACHE` points at the dedicated cache;
user-provided environment variables are merged without losing the required
cache value.

The job has `RunAtLoad` and `KeepAlive` enabled, so it starts at login and is
restarted after failure. It writes stdout and stderr to distinct files under
`/tmp`, following the repository's existing Darwin service convention.

The router exposes llama.cpp's OpenAI-compatible API. Clients select a model by
putting its declared Hugging Face ID in the request's `model` field. The server
autoloads that model when a request first needs it.

### Model synchronization job

`llama-cpp-model-sync` is a background launchd job backed by a Nix-generated
shell application. The desired model list is serialized as JSON at evaluation
time; shell interpolation never parses model identifiers. The application uses
store-pinned `curl` and `jq` binaries.

The job runs when loaded and every 15 minutes afterward. Each run:

1. Waits for the router's `/models` endpoint, with a finite timeout.
2. Calls `GET /models?reload=1` to refresh the router inventory.
3. Cancels or unloads every model absent from the desired list.
4. Calls `DELETE /models?model=...` for each undeclared cached model.
5. Calls `POST /models` for each declared model not already present.
6. Exits after the router accepts the requests.

Model downloads belong to the persistent router process and continue after the
synchronizer exits. Consequently, activation and `darwin-rebuild` never wait
for a multi-gigabyte transfer. Repeated runs are idempotent and recover from a
server restart, interrupted transfer, or temporary network failure.

Removal is eventually consistent. If an undeclared model is still downloading,
the synchronizer first asks the router to cancel it; a later run removes any
completed cache artifact. Reconciliation is strictly limited to `cacheDir` and
must not remove files from the user's general Hugging Face cache.

## Errors and Observability

The server and synchronizer use separate stdout and stderr logs under `/tmp`.
A malformed model ID, rejected API request, or failed transfer is logged by the
router and does not stop the HTTP service. A synchronizer run that cannot reach
the server exits unsuccessfully after its timeout; launchd's scheduled retry
provides recovery without a tight restart loop.

The HTTP API binds only to localhost by default. No API key is required for
this local-only design. A user who overrides `host` to expose the service is
responsible for adding suitable authentication and network controls through
llama-server arguments.

An empty `models` list is valid. The router still runs, and reconciliation
removes all artifacts from the dedicated declarative cache.

## Host Migration

Update `hosts/mac-2026.nix` from `services.ollama.enable = true` to:

```nix
services.llama-cpp = {
  enable = true;
  models = [
    "ggml-org/Qwen3.6-35B-A3B-GGUF:Q4_K_M"
  ];
};
```

No compatibility aliases for `services.ollama` are retained. This is an
intentional replacement, and a search of all Nix sources must find no remaining
Ollama configuration or package reference.

## Verification

Automated verification must not download the model. It covers:

- Nix formatting and flake evaluation.
- Building the `mac-2026` Darwin configuration.
- Evaluating that the enabled module adds `pkgs.llama-cpp`.
- Evaluating the server and synchronization launchd definitions, including
  address, port, cache, and desired model data.
- Exercising the generated reconciliation script against a fake local HTTP
  endpoint, independently of launchd, to cover additions, removals, and an
  unreachable server.
- Searching all Nix sources for stale Ollama references.

After the user applies the configuration, runtime smoke checks are:

```sh
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/models
curl http://127.0.0.1:8080/v1/models
```

Acceptance requires the following behavior:

- llama-server starts in the background and survives login and process failure.
- `darwin-rebuild` completes without waiting for model downloads.
- The Qwen GGUF model appears in `/models` after its download completes.
- Requests can autoload the declared model through router mode.
- Removing a model from Nix eventually removes it from the dedicated cache.
- Setting `enable = false` removes the package and both jobs while retaining the
  cache.
- No Ollama reference remains in the Nix configuration.
