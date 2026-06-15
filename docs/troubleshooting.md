# Troubleshooting

## Confirm the expected kernel and GPU

```bash
uname -r
/opt/rocm/bin/rocminfo | grep -E 'Name:|Marketing Name:' | head -n 20
/opt/rocm/bin/amd-smi static --asic --vram --driver
```

Expected:

- kernel name ends in `-generic`
- GPU ISA is `gfx1151`
- VRAM is about 98,304MB with a 96GB firmware allocation

## Inspect the service

```bash
systemctl --user status qwen-server --no-pager -l
journalctl --user -u qwen-server -n 200 --no-pager
```

## Inspect kernel GPU faults

```bash
sudo journalctl -k -b --no-pager |
  grep -Ei 'amdgpu|page fault|GPU fault|GPUVM|GCVM|CPF'
```

CPF or GPUVM mapping faults during a minimal HIP test indicate a kernel/driver
problem, not a model parameter problem. Boot the selected HWE generic kernel
and verify that ROCm was installed with `--no-dkms`.

## Check memory allocation

```bash
free -h
cat /sys/class/drm/card0/device/mem_info_vram_total
cat /sys/class/drm/card0/device/mem_info_vram_used
```

When firmware assigns 96GB to the GPU, Linux sees only about 30GB as ordinary
system RAM. This is expected on the tested 128GB machine.

## Rebuild cleanly

Use a new build directory rather than modifying the pinned source tree:

```bash
rm -rf "$HOME/llama.cpp/build-hip-721"
./scripts/build-llama.sh
systemctl --user restart qwen-server
./scripts/smoke-test.sh
```

## Port already in use

```bash
ss -ltnp | grep ':8080'
```

Stop the conflicting process or change `PORT` in `config.env`, then rerun:

```bash
./scripts/install-service.sh
./scripts/smoke-test.sh
```

## Model download recovery

Downloads use `.part` files and `curl --continue-at -`. Rerun:

```bash
./scripts/download-models.sh
```

Completed files are checked against pinned SHA-256 values before use.
