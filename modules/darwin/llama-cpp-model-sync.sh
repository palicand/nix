set -euo pipefail

base_url="${LLAMA_CPP_BASE_URL:-http://127.0.0.1:8080}"
models_file="${LLAMA_CPP_MODELS_FILE:?LLAMA_CPP_MODELS_FILE must point to desired-model JSON}"
max_attempts="${LLAMA_CPP_MAX_ATTEMPTS:-60}"
retry_delay="${LLAMA_CPP_RETRY_DELAY:-1}"
connect_timeout="${LLAMA_CPP_CONNECT_TIMEOUT:-2}"
request_timeout="${LLAMA_CPP_REQUEST_TIMEOUT:-10}"
curl_bin="${LLAMA_CPP_CURL:-curl}"

require_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$name must be a positive integer" >&2
    exit 2
  fi
}

require_nonnegative_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "$name must be a nonnegative integer" >&2
    exit 2
  fi
}

require_positive_integer LLAMA_CPP_MAX_ATTEMPTS "$max_attempts"
require_nonnegative_integer LLAMA_CPP_RETRY_DELAY "$retry_delay"
require_positive_integer LLAMA_CPP_CONNECT_TIMEOUT "$connect_timeout"
require_positive_integer LLAMA_CPP_REQUEST_TIMEOUT "$request_timeout"

curl_args=(
  --fail
  --silent
  --show-error
  --connect-timeout "$connect_timeout"
  --max-time "$request_timeout"
)

attempt=1
while ! inventory="$("$curl_bin" "${curl_args[@]}" "$base_url/models?reload=1")"; do
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
  "$curl_bin" "${curl_args[@]}" \
    --request POST \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$base_url/models/unload" >/dev/null 2>&1 || true
  "$curl_bin" "${curl_args[@]}" \
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
  "$curl_bin" "${curl_args[@]}" \
    --request POST \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$base_url/models" >/dev/null
done < <(jq --raw-output '.[]' "$models_file")
