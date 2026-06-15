#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/config.env"

JOBS="${JOBS:-$(nproc)}"
LLAMA_COMMIT="${LLAMA_COMMIT:-18ef86ecec723361362a332a79b4d913fd724d40}"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -x /opt/rocm/bin/rocminfo ]] || die "ROCm is not installed."
/opt/rocm/bin/rocminfo 2>/dev/null | grep -F gfx1151 >/dev/null ||
    die "ROCm does not detect gfx1151."

if [[ ! -d "$LLAMA_DIR/.git" ]]; then
    log "Cloning llama.cpp"
    git clone https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
fi

if [[ -n "$(git -C "$LLAMA_DIR" status --porcelain --untracked-files=no)" ]]; then
    die "$LLAMA_DIR has modified tracked files. Use a clean LLAMA_DIR."
fi

log "Checking out verified llama.cpp commit $LLAMA_COMMIT"
git -C "$LLAMA_DIR" fetch origin "$LLAMA_COMMIT"
git -C "$LLAMA_DIR" checkout --detach "$LLAMA_COMMIT"

if [[ -x "$BUILD_DIR/bin/llama-server" ]] &&
    "$BUILD_DIR/bin/llama-server" --version 2>&1 |
        grep -q "${LLAMA_COMMIT:0:9}"; then
    log "Verified llama-server build already exists"
    exit 0
fi

log "Building llama.cpp for gfx1151"
export HIPCXX HIP_PATH
HIPCXX="$(/opt/rocm/bin/hipconfig -l)/clang"
HIP_PATH="$(/opt/rocm/bin/hipconfig -p)"
LLAMA_HIP_UMA=1 cmake -S "$LLAMA_DIR" -B "$BUILD_DIR" --fresh \
    -DGGML_HIP=ON \
    -DGGML_VULKAN=OFF \
    -DGPU_TARGETS=gfx1151 \
    -DGGML_HIP_ROCWMMA_FATTN=OFF \
    -DGGML_NATIVE=ON \
    -DLLAMA_CURL=OFF \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --target llama-server -j "$JOBS"
"$BUILD_DIR/bin/llama-server" --version
