#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$ROOT_DIR/config.env}"
# shellcheck disable=SC1090
source "$CONFIG_FILE"

MODEL_DIR="$MODEL_ROOT/Qwen3.6-27B-GGUF"
MODEL_FILE="$MODEL_DIR/Qwen_Qwen3.6-27B-Q8_0.gguf"
MTP_FILE="$MODEL_DIR/mtp-Qwen_Qwen3.6-27B-Q8_0.gguf"

export LLAMA_HIP_UMA=1
export GGML_HIPBLAS=1

exec "$BUILD_DIR/bin/llama-server" \
    --model "$MODEL_FILE" \
    --alias "$MODEL_ALIAS" \
    --host "$HOST" \
    --port "$PORT" \
    --ctx-size "$CTX_SIZE" \
    --parallel 1 \
    --cache-ram 0 \
    --n-gpu-layers 99 \
    --fit off \
    --flash-attn on \
    --threads "$THREADS" \
    --threads-batch "$THREADS_BATCH" \
    --prio 2 \
    --poll 100 \
    --spec-type draft-mtp \
    --spec-draft-model "$MTP_FILE" \
    --spec-draft-ngl 99 \
    --spec-draft-n-max 5
