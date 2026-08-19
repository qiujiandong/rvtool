# RISC-V Toolchain

[![Build rvtool Docker Image](https://github.com/qiujiandong/rvtool/actions/workflows/rvtool.yml/badge.svg)](https://github.com/qiujiandong/rvtool/actions/workflows/rvtool.yml)
[![GHCR](https://img.shields.io/badge/GHCR-rvtool-181717?logo=github)](https://github.com/qiujiandong/rvtool/pkgs/container/rvtool)

Source-built RISC-V toolchains packaged as a Docker image. The image provides
multilib GNU GCC toolchains for ELF and Linux targets, plus host Clang/LLD with
RISC-V wrappers. It intentionally does not include QEMU.

## Images

<!-- images:start -->
| Image | Architecture | Upstream release | Size |
| --- | --- | --- | --- |
| [`ghcr.io/qiujiandong/rvtool:latest`](https://github.com/qiujiandong/rvtool/pkgs/container/rvtool) | `linux/amd64` | [`2026.07.15`](https://github.com/riscv-collab/riscv-gnu-toolchain/releases/tag/2026.07.15) | 1.57 GB |
| [`ghcr.io/qiujiandong/rvtool:2026.07.15`](https://github.com/qiujiandong/rvtool/pkgs/container/rvtool) | `linux/amd64` | [`2026.07.15`](https://github.com/riscv-collab/riscv-gnu-toolchain/releases/tag/2026.07.15) | 1.57 GB |
<!-- images:end -->

After publishing, refresh this table with an authenticated `gh` session (or set
`GH_TOKEN` to a token that has `read:packages`):

```sh
scripts/update-readme-images.sh
```

Pull and open a shell:

```sh
docker run --rm -it -v "$PWD:/work" -w /work ghcr.io/qiujiandong/rvtool:latest bash
```

## Included tools

The following are the primary tools; the image also includes supporting GNU
binutils and runtime commands.

| Category | Commands | Notes |
| --- | --- | --- |
| Bare-metal GNU toolchain | `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-g++` | Multilib GCC for ELF targets. |
| Linux GNU toolchain | `riscv64-unknown-linux-gnu-gcc`, `riscv64-unknown-linux-gnu-g++` | Multilib GCC for Linux targets. |
| LLVM toolchain | `clang`, `clang++`, `ld.lld` | Host LLVM tools with RISC-V targets enabled. |
| RISC-V Clang wrappers | `riscv64-unknown-elf-clang`, `riscv64-unknown-elf-clang++`, `riscv64-unknown-linux-gnu-clang`, `riscv64-unknown-linux-gnu-clang++` | Select the matching target and GNU sysroot automatically. |
| Build tools | `make`, `cmake`, `ninja`, `python3`, and `pkg-config` | Available for building projects in the container. |

GNU GCC multilib variants available in this image:

ELF:

- `rv32i/ilp32`
- `rv32im/ilp32`
- `rv32iac/ilp32`
- `rv32imac/ilp32`
- `rv32imafc/ilp32f`
- `rv64imac/lp64`
- `rv64imafdc/lp64d`

Linux:

- `rv32imac/ilp32`
- `rv32imafdc/ilp32d`
- `rv64imac/lp64`
- `rv64imafdc/lp64d`

Clang is built with `riscv32`, `riscv32be`, `riscv64`, and `riscv64be`
backends (as well as host `x86` and `x86-64`). The provided wrappers configure
GNU toolchains and sysroots only for `riscv64-unknown-elf` and
`riscv64-unknown-linux-gnu`.

QEMU is not included; run the produced binaries with an emulator or target
environment supplied by your project.

## Build locally

For a Linux host building both `amd64` and `arm64` with QEMU, register the
binfmt handlers after each host boot:

```sh
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx create \
  --name rvtool-builder \
  --driver docker-container \
  --use \
  --bootstrap
docker buildx inspect --bootstrap
```

The registration lives in the host kernel and normally does not survive a
reboot. Add the first command to the host's startup configuration, or run it
when a temporary CI runner starts. Docker Desktop already provides the
required emulation support. The GitHub Actions runner uses the host's existing
Docker Buildx and binfmt setup.

Choose an upstream `riscv-gnu-toolchain` Release tag and run:

```sh
docker build --network=host \
  --build-arg RISCV_GNU_TOOLCHAIN_REF=<upstream-release-tag> \
  -t rvtool:local .
```

`--network=host` lets the build access a proxy running on the Docker host.

## Publishing

Pushing to `main` or running `workflow_dispatch` starts the self-hosted GitHub
Actions workflow. It selects the latest upstream Release, skips an already
published version tag, and otherwise publishes both `latest` and the upstream
release tag to GHCR.
