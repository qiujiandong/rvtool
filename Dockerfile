FROM debian:bookworm AS builder

ARG RISCV_GNU_TOOLCHAIN_REF
ARG RISCV_GNU_TOOLCHAIN_URL=https://github.com/riscv-collab/riscv-gnu-toolchain.git

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake autotools-dev bison build-essential ca-certificates cmake curl \
    flex gawk gperf git libexpat-dev libgmp-dev libmpc-dev libmpfr-dev \
    libncurses-dev libslirp-dev libtool ninja-build patchutils python3 texinfo \
    zlib1g-dev && rm -rf /var/lib/apt/lists/*

RUN test -n "$RISCV_GNU_TOOLCHAIN_REF" && test -n "$RISCV_GNU_TOOLCHAIN_URL" && \
    git config --global url."https://github.com/gnutools/binutils-gdb.git".insteadOf \
    https://sourceware.org/git/binutils-gdb.git && \
    git config --global url."https://github.com/gnutools/glibc.git".insteadOf \
    https://sourceware.org/git/glibc.git && \
    git config --global url."https://github.com/mirror/newlib-cygwin.git".insteadOf \
    https://sourceware.org/git/newlib-cygwin.git && \
    git config --global url."https://gnu.googlesource.com/dejagnu".insteadOf \
    https://git.savannah.gnu.org/git/dejagnu.git && \
    git clone --depth=1 --branch "$RISCV_GNU_TOOLCHAIN_REF" --recurse-submodules \
    --shallow-submodules "$RISCV_GNU_TOOLCHAIN_URL" /src

RUN mkdir /build-elf && cd /build-elf && \
    /src/configure --prefix=/opt/rvtool/elf --enable-multilib --disable-gdb \
    --with-languages=c,c++ --enable-strip && \
    make -j"$(nproc)"

RUN mkdir /build-linux && cd /build-linux && \
    /src/configure --prefix=/opt/rvtool/linux --enable-multilib --disable-gdb \
    --with-languages=c,c++ --enable-strip --enable-default-pie && \
    make -j"$(nproc)" linux

RUN cmake -S /src/llvm/llvm -B /build-llvm -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/rvtool/llvm \
    -DLLVM_ENABLE_PROJECTS='clang;lld' \
    -DLLVM_TARGETS_TO_BUILD='X86;RISCV' && \
    cmake --build /build-llvm --target install --parallel "$(nproc)"

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash cmake libedit2 libgmp10 libmpc3 libmpfr6 libtinfo6 libxml2 libzstd1 \
    make ninja-build pkg-config python3 zlib1g && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/rvtool /opt/rvtool
COPY scripts/rvtool-clang /usr/local/bin/riscv64-unknown-elf-clang
COPY scripts/rvtool-clang /usr/local/bin/riscv64-unknown-elf-clang++
COPY scripts/rvtool-clang /usr/local/bin/riscv64-unknown-linux-gnu-clang
COPY scripts/rvtool-clang /usr/local/bin/riscv64-unknown-linux-gnu-clang++

RUN chmod +x /usr/local/bin/riscv64-unknown-*-clang*

ENV PATH=/opt/rvtool/elf/bin:/opt/rvtool/linux/bin:/opt/rvtool/llvm/bin:$PATH
WORKDIR /work
CMD ["bash"]
