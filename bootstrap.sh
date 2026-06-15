#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$ROOT_DIR/config.env" ]]; then
    cp "$ROOT_DIR/config.env.example" "$ROOT_DIR/config.env"
    printf 'Created %s from the defaults.\n' "$ROOT_DIR/config.env"
fi

"$ROOT_DIR/scripts/install-rocm.sh"

if [[ "$(uname -r)" != *-generic ]]; then
    cat <<'EOF'

The HWE generic kernel is installed and selected, but it is not running yet.
Reboot, return to this directory, and run ./bootstrap.sh again.
EOF
    exit 2
fi

"$ROOT_DIR/scripts/build-llama.sh"
"$ROOT_DIR/scripts/download-models.sh"
"$ROOT_DIR/scripts/install-service.sh"
"$ROOT_DIR/scripts/smoke-test.sh"

printf '\nSetup complete. API base: http://127.0.0.1:%s/v1\n' \
    "$("$ROOT_DIR/scripts/read-config.sh" PORT)"
