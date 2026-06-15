# Implementation Journey

This document records the approaches tried on the Ryzen AI MAX+ 395 host and
the combination that finally produced stable, fully offloaded inference.

## Starting point

The target was local serving of recent Qwen and Gemma GGUF models on the
Radeon 8060S integrated GPU. The machine has 128GB unified memory with 96GB
assigned to VRAM in firmware.

## Attempts

### PyTorch and vLLM

ROCm PyTorch environments were tested with Qwen3.6-35B-A3B. Package and GPU
support across the available wheel indexes did not produce a reliable serving
stack for `gfx1151`. The Python environment also added more moving parts than
needed for GGUF inference.

Conclusion: not used for the final setup.

### llama.cpp with Vulkan

llama.cpp was built with `GGML_VULKAN=ON` after installing the Vulkan SDK,
shader compiler, and SPIR-V tooling. This was useful as a compatibility path,
but ROCm/HIP was the better-performing and better-observed backend once the
driver/kernel issue was resolved.

Conclusion: viable fallback, not the final backend.

### ROCm builds with the wrong target

Builds were attempted with `gfx1101`, including rocBLAS library workarounds.
The actual device target reported by `rocminfo` is `gfx1151`; explicitly
building for that target removed the need for target spoofing.

Conclusion: always confirm the device ISA with `rocminfo`.

### AMDGPU DKMS and OEM kernel

AMD repository packages and an out-of-tree `amdgpu-dkms` path were tried. The
Ubuntu OEM `6.17.0-1025-oem` kernel then showed repeatable CPF GPUVM mapping
faults. A minimal HIP smoke program failed, proving the fault was below
llama.cpp and the model.

Conclusion: do not debug model settings while a minimal HIP program fails.

## Successful approach

1. Install the Ubuntu HWE generic kernel.
2. Install AMD's official ROCm 7.2.1 userspace with `--no-dkms`.
3. Use the Ubuntu inbox `amdgpu` driver from the HWE generic kernel.
4. Confirm that `rocminfo` reports `gfx1151`.
5. Build pinned llama.cpp with `GGML_HIP=ON` and `GPU_TARGETS=gfx1151`.
6. Set `LLAMA_HIP_UMA=1`.
7. Fully offload Qwen3.6-27B Q8_0 and its Q8 MTP draft model.
8. Run the server as a persistent `systemd --user` service.

## Verified result

On June 15, 2026, the running service reported:

- API health: `ok`
- Model parameters: 27,320,697,856
- Model size: 29,105,393,664 bytes
- Context: 32,768
- Generation: approximately 27.4 tokens/s in a short API test
- MTP draft acceptance: 25 of 25 draft tokens in that test

Short benchmarks are workload-dependent. Treat the number as a functional
reference, not a general performance guarantee.
