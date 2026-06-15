#!/usr/bin/env bash
set -Eeuo pipefail

ROCM_VERSION="7.2.1"
INSTALLER="amdgpu-install_7.2.1.70201-1_all.deb"
INSTALLER_SHA256="4c0338a241c15b12c14eb3aeb4012ea0d55dba681737ea8482248041a16c2afa"
INSTALLER_URL="https://repo.radeon.com/amdgpu-install/7.2.1/ubuntu/noble/$INSTALLER"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -r /etc/os-release ]] || die "Cannot identify the operating system."
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] ||
    die "This script supports Ubuntu 24.04 only."

sudo -v

log "Installing the HWE kernel and build dependencies"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    linux-generic-hwe-24.04 \
    build-essential cmake git curl jq libssl-dev ca-certificates

if [[ ! -x /opt/rocm/bin/rocminfo ]] ||
    ! dpkg-query -W -f='${Version}' rocm-core 2>/dev/null |
        grep -q "^${ROCM_VERSION}"; then
    log "Installing AMD ROCm $ROCM_VERSION userspace without DKMS"
    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT
    curl --fail --location --retry 5 \
        --output "$work_dir/$INSTALLER" "$INSTALLER_URL"
    printf '%s  %s\n' "$INSTALLER_SHA256" "$work_dir/$INSTALLER" |
        sha256sum --check --status ||
        die "AMDGPU installer checksum failed."
    sudo apt-get install -y "$work_dir/$INSTALLER"

    sudo tee /etc/apt/preferences.d/00-rocm-721-pin >/dev/null <<'EOF'
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 1001
EOF
    sudo apt-get update
    sudo amdgpu-install -y --usecase=rocm --no-dkms --allow-downgrades
else
    log "ROCm $ROCM_VERSION is already installed"
fi

log "Selecting the newest installed HWE generic kernel"
sudo tee /etc/default/grub.d/90-strix-halo-kernel.cfg >/dev/null <<'EOF'
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=false
EOF
sudo update-grub
hwe_kernel="$(
    find /boot -maxdepth 1 -name 'vmlinuz-*-generic' -printf '%f\n' |
        sed 's/^vmlinuz-//' | sort -V | tail -n 1
)"
[[ -n "$hwe_kernel" ]] || die "No generic HWE kernel was installed."
sudo grub-set-default \
    "Advanced options for Ubuntu>Ubuntu, with Linux $hwe_kernel"

log "ROCm userspace and kernel selection are ready"
printf 'Selected kernel: %s\nRunning kernel:  %s\n' "$hwe_kernel" "$(uname -r)"
