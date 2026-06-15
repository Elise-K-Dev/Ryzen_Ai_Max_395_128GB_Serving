#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/config.env"

MODEL_DIR="$MODEL_ROOT/Qwen3.6-27B-GGUF"
MODEL_FILE="$MODEL_DIR/Qwen_Qwen3.6-27B-Q8_0.gguf"
MTP_FILE="$MODEL_DIR/mtp-Qwen_Qwen3.6-27B-Q8_0.gguf"
MODEL_SHA256="aca14ee02bc555ce6703fd0e7d4518c92e731bc3b3d05b1af428fd015c28286f"
MTP_SHA256="106fb39ab1cd37373fc54cf9c12b101739aecbbe215725cc0d9dbb25fa495ac4"
HF_BASE="https://huggingface.co/bartowski/Qwen_Qwen3.6-27B-GGUF/resolve/main"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

download_and_verify() {
    local url="$1" output="$2" expected="$3"

    if [[ -f "$output" ]] &&
        printf '%s  %s\n' "$expected" "$output" |
            sha256sum --check --status; then
        log "Already verified: $(basename "$output")"
        return
    fi

    log "Downloading $(basename "$output")"
    curl --fail --location --retry 10 --retry-all-errors \
        --continue-at - --output "$output.part" "$url"
    mv "$output.part" "$output"
    printf '%s  %s\n' "$expected" "$output" |
        sha256sum --check --status ||
        die "Checksum verification failed for $output"
}

mkdir -p "$MODEL_DIR"
download_and_verify \
    "$HF_BASE/Qwen_Qwen3.6-27B-Q8_0.gguf?download=true" \
    "$MODEL_FILE" "$MODEL_SHA256"
download_and_verify \
    "$HF_BASE/mtp-Qwen_Qwen3.6-27B-Q8_0.gguf?download=true" \
    "$MTP_FILE" "$MTP_SHA256"
