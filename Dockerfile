##############################
# Stage 1: Build Stage
#############################
FROM alpine:3.23.3 AS builder

RUN apk update && apk add \
    bash-completion alpine-sdk zlib-dev xz texinfo curl

ENV NAME=hyperscan-toolchain
ENV WORKING_DIR=/working-dir
ENV TARGET=score-elf
ENV PREFIX=/opt/hyperscan-toolchain

ENV PATH=$PREFIX/bin:$PATH
ENV BINUTILS_VERSION=2.35.2
ENV GCC_VERSION=14.3.0
ENV NEWLIB_VERSION=4.6.0.20260123
ENV THREADS=8

WORKDIR $WORKING_DIR

# Download sources
RUN curl -C - --progress-bar \
    https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2 \
    -o binutils-$BINUTILS_VERSION.tar.bz2

RUN curl -C - --progress-bar \
    https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz \
    -o gcc-$GCC_VERSION.tar.xz

RUN curl -C - --progress-bar \
    ftp://sourceware.org/pub/newlib/newlib-$NEWLIB_VERSION.tar.gz \
    -o newlib-$NEWLIB_VERSION.tar.gz

# Download patches
RUN curl -L --progress-bar \
    https://raw.githubusercontent.com/LiraNuna/hyperscan-emulator/master/tools/binutils-patch.diff \
    -o binutils-patch.diff

RUN curl -L --progress-bar \
    https://raw.githubusercontent.com/LiraNuna/hyperscan-emulator/master/tools/gcc-patch.diff \
    -o gcc-patch.diff

RUN curl -L --progress-bar \
    https://raw.githubusercontent.com/LiraNuna/hyperscan-emulator/refs/heads/master/tools/newlib-patch.diff \
    -o newlib-patch.diff

# Extract
RUN tar xf binutils-$BINUTILS_VERSION.tar.bz2
RUN tar xf gcc-$GCC_VERSION.tar.xz
RUN tar xf newlib-$NEWLIB_VERSION.tar.gz

# Patch toolchain components
WORKDIR $WORKING_DIR/binutils-$BINUTILS_VERSION
RUN patch -p0 < ../binutils-patch.diff

WORKDIR $WORKING_DIR/gcc-$GCC_VERSION
RUN patch -p0 < ../gcc-patch.diff

WORKDIR $WORKING_DIR/newlib-$NEWLIB_VERSION
RUN patch -l -p0 < ../newlib-patch.diff

# Compiling binutils...
WORKDIR $WORKING_DIR/build-binutils
RUN $WORKING_DIR/binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix=$PREFIX --disable-nls --disable-multilib --disable-static  -v
RUN make -j$THREADS all
RUN make install

# Compiling first stage GCC...
WORKDIR $WORKING_DIR/gcc-$GCC_VERSION
RUN ./contrib/download_prerequisites

WORKDIR $WORKING_DIR/build-gcc
RUN $WORKING_DIR/gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX --without-headers --with-newlib --enable-obsolete \
    --disable-libgomp --disable-libmudflap --disable-libssp --disable-libatomic --disable-libitm --disable-libsanitizer \
    --disable-libmpc --disable-libquadmath --disable-threads --disable-multilib --disable-target-zlib --with-system-zlib \
    --disable-shared --disable-nls --disable-lto --disable-libstdcxx --enable-languages=c --with-gnu-as --with-gnu-ld -v

RUN make -j$THREADS all-gcc all-target-libgcc
RUN make install-gcc install-target-libgcc

# Compiling Newlib...
WORKDIR $WORKING_DIR/build-newlib
RUN $WORKING_DIR/newlib-$NEWLIB_VERSION/configure --target=$TARGET --prefix=$PREFIX \
    --with-gnu-as --with-gnu-ld --disable-nls --disable-multilib --disable-newlib-supplied-syscalls

RUN make all -j$THREADS
RUN make install

# Compiling second stage GCC (C++)...
WORKDIR $WORKING_DIR/build-gcc-stage2
RUN $WORKING_DIR/gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX --with-newlib --enable-obsolete \
    --disable-libgomp --disable-libmudflap --disable-libssp --disable-libatomic --disable-libitm --disable-libsanitizer \
    --disable-libmpc --disable-libquadmath --disable-threads --disable-multilib --disable-target-zlib --with-system-zlib \
    --disable-shared --disable-nls --disable-lto --enable-languages=c,c++ --with-gnu-as --with-gnu-ld -v

RUN make -j$THREADS all
RUN make install

##############################
# Stage 2: Runtime Stage
#############################
# Use a minimal base image or even scratch if statically linked
FROM alpine:3.23.3 AS runtime

ENV TOOLCHAIN=/opt/hyperscan-toolchain
ENV PATH=$TOOLCHAIN/bin:$PATH

# Copy the compiled binary from the builder stage
COPY --from=builder /opt/hyperscan-toolchain $TOOLCHAIN

WORKDIR /workspace