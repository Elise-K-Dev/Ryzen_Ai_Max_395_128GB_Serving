#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$ROOT_DIR/config.env}"

[[ -f "$CONFIG_FILE" ]] || {
    printf 'Missing %s. Copy config.env.example to config.env first.\n' \
        "$CONFIG_FILE" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if (($#)); then
    printf '%s\n' "${!1:-}"
fi
