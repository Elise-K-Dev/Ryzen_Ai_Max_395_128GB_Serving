#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/config.env"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -r)" == *-generic ]] ||
    die "Boot the selected Ubuntu HWE generic kernel."
/opt/rocm/bin/rocminfo 2>/dev/null | grep -F gfx1151 >/dev/null ||
    die "ROCm does not detect gfx1151."

printf 'Waiting for llama-server to become healthy'
for _ in $(seq 1 180); do
    if curl --fail --silent --max-time 2 \
        "http://127.0.0.1:$PORT/health" >/dev/null; then
        printf '\n'
        break
    fi
    printf '.'
    sleep 1
done

curl --fail --silent --max-time 2 \
    "http://127.0.0.1:$PORT/health" >/dev/null ||
    die "Server is unhealthy. Check: journalctl --user -u qwen-server -n 100"

response="$(
    curl --fail --silent --max-time 120 \
        "http://127.0.0.1:$PORT/v1/chat/completions" \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"$MODEL_ALIAS\",
            \"messages\": [{
                \"role\": \"user\",
                \"content\": \"Reply exactly: SERVING_OK\"
            }],
            \"temperature\": 0,
            \"max_tokens\": 16,
            \"chat_template_kwargs\": {\"enable_thinking\": false}
        }"
)"

reply="$(jq -r '.choices[0].message.content // empty' <<<"$response")"
[[ "$reply" == *"SERVING_OK"* ]] ||
    die "Unexpected API response: $reply"

jq '{
    status: "ok",
    reply: .choices[0].message.content,
    prompt_tokens_per_second: .timings.prompt_per_second,
    generation_tokens_per_second: .timings.predicted_per_second,
    draft_tokens: .timings.draft_n,
    accepted_draft_tokens: .timings.draft_n_accepted
}' <<<"$response"
