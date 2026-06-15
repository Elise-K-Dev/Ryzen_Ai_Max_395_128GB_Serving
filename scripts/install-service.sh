#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/qwen-server.service"

mkdir -p "$SERVICE_DIR"

[[ "$ROOT_DIR" != *'"'* && "$ROOT_DIR" != *'%'* ]] || {
    printf 'Repository path cannot contain a double quote or %%: %s\n' \
        "$ROOT_DIR" >&2
    exit 1
}

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Qwen 3.6 27B Dense Q8 ROCm inference server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="CONFIG_FILE=$ROOT_DIR/config.env"
ExecStart="$ROOT_DIR/scripts/run-server.sh"
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF

if [[ "$(loginctl show-user "$USER" -p Linger --value)" != "yes" ]]; then
    sudo loginctl enable-linger "$USER"
fi

systemctl --user daemon-reload
systemctl --user enable qwen-server.service
systemctl --user restart qwen-server.service
