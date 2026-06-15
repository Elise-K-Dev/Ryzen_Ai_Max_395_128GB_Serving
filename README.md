# Ryzen AI MAX+ 395 128GB LLM Serving

Reproducible ROCm inference setup for the AMD Ryzen AI MAX+ 395
(`gfx1151`) with 128GB unified memory.

The verified configuration serves Qwen3.6-27B Dense Q8_0 through llama.cpp's
OpenAI-compatible API. The model and its Q8 MTP draft model are fully
offloaded to the Radeon 8060S.

## Verified configuration

| Component | Version / setting |
| --- | --- |
| Hardware | Ryzen AI MAX+ 395, Radeon 8060S, 128GB unified memory |
| BIOS UMA allocation | 96GB |
| OS | Ubuntu 24.04.4 LTS |
| Kernel | Ubuntu HWE `6.17.0-35-generic` |
| ROCm | AMD official 7.2.1 userspace |
| GPU target | `gfx1151` |
| llama.cpp | `18ef86ecec723361362a332a79b4d913fd724d40` (build 9596) |
| Model | Qwen3.6-27B Dense Q8_0 |
| Draft model | Qwen3.6-27B Q8_0 MTP |
| Context | 32,768 tokens |
| Measured generation | about 27.4 tokens/s on the verified host |

With 96GB assigned as VRAM, Linux reports about 30GB system RAM. This is
expected for this UMA split.

## Quick start

On a fresh Ubuntu 24.04 installation:

```bash
git clone https://github.com/Elise-K-Dev/Ryzen_Ai_Max_395_128GB_Serving.git
cd Ryzen_Ai_Max_395_128GB_Serving
cp config.env.example config.env
./bootstrap.sh
```

If the script installs or selects the HWE generic kernel, reboot and run the
same command again:

```bash
sudo reboot
# After reconnecting:
cd Ryzen_Ai_Max_395_128GB_Serving
./bootstrap.sh
```

The script is idempotent. It installs ROCm, builds llama.cpp, downloads and
verifies the model files, installs a persistent user service, and runs an API
smoke test.

The downloads require roughly 33GB. Keep at least 45GB free for models,
source, build output, and temporary files.

## Use the API

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/v1/models

curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.6-27b-dense",
    "messages": [{"role": "user", "content": "Reply exactly: SERVING_OK"}],
    "temperature": 0,
    "max_tokens": 16,
    "chat_template_kwargs": {"enable_thinking": false}
  }'
```

Service management:

```bash
systemctl --user status qwen-server
journalctl --user -u qwen-server -f
systemctl --user restart qwen-server
systemctl --user stop qwen-server
./scripts/smoke-test.sh
```

## Configuration

Edit `config.env` before running `bootstrap.sh`. Common overrides:

```bash
MODEL_ROOT=/data/models
PORT=8081
CTX_SIZE=65536
HOST=127.0.0.1
```

`HOST=0.0.0.0` exposes the unauthenticated API to the network. Use a firewall
or an authenticated reverse proxy outside a trusted LAN.

## Why this setup

The important compatibility decision is the kernel/driver combination:

- Use AMD's official ROCm 7.2.1 userspace.
- Pass `--no-dkms` to keep Ubuntu's inbox `amdgpu` kernel driver.
- Boot the Ubuntu HWE generic kernel.
- Build llama.cpp specifically for `gfx1151`.
- Set `LLAMA_HIP_UMA=1` for the unified-memory APU.

The OEM `6.17.0-1025-oem` kernel produced repeatable CPF GPUVM mapping faults,
including with a minimal HIP program. The HWE generic kernel passed that test
and runs the fully offloaded model.

See [docs/journey.md](docs/journey.md) for attempted approaches and
[docs/troubleshooting.md](docs/troubleshooting.md) for diagnostics.

## Repository layout

```text
bootstrap.sh                 End-to-end idempotent setup
config.env.example           User-adjustable paths and server settings
scripts/install-rocm.sh      Kernel, dependencies, and ROCm userspace
scripts/build-llama.sh       Pinned gfx1151 llama.cpp build
scripts/download-models.sh   Resumable, checksum-verified downloads
scripts/install-service.sh   Persistent systemd user service
scripts/run-server.sh        llama-server launch command
scripts/smoke-test.sh        ROCm and OpenAI API validation
docs/journey.md              Experiments, failures, and final approach
docs/troubleshooting.md      Recovery and inspection commands
```

## Scope

This repository is intentionally pinned to the versions that worked on the
tested machine. New ROCm, kernel, llama.cpp, or model versions should be
validated independently before changing the defaults.
