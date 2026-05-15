FROM alpine:3.23.3 AS builder-base

ARG BINUTILS_VERSION=2.46.0
ARG GCC_VERSION=14.3.0
ARG NEWLIB_VERSION=4.6.0.20260123

ENV TARGET=score-elf \
    PREFIX=/opt/score-toolchain \
    BINUTILS_VERSION=${BINUTILS_VERSION} \
    GCC_VERSION=${GCC_VERSION} \
    NEWLIB_VERSION=${NEWLIB_VERSION} \
    PATH=/opt/score-toolchain/bin:/usr/local/bin:${PATH}

RUN apk add --no-cache \
    alpine-sdk \
    bison \
    flex \
    texinfo \
    gawk \
    patch \
    curl \
    ca-certificates \
    xz \
    bzip2 \
    gzip \
    tar \
    make \
    cmake \
    ninja-build \
    python3 \
    git \
    automake \
    libtool \
    m4 \
    perl \
    help2man \
    zlib-dev \
    file \
    pkgconfig \
    rsync \
    vim \
    less

# Force unversioned autotools commands to use 2.69.
RUN curl -O http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz; \
    tar zxvf autoconf-2.69.tar.gz; \
    cd autoconf-2.69; \
    ./configure; \
    make; \
    make install

FROM builder-base AS builder

WORKDIR /build

COPY patches /patches

RUN set -eux; \
    curl -L --fail "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.bz2" -o binutils.tar.bz2; \
    curl -L --fail "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" -o gcc.tar.xz; \
    curl -L --fail "https://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz" -o newlib.tar.gz; \
    tar xf binutils.tar.bz2; \
    tar xf gcc.tar.xz; \
    tar xf newlib.tar.gz; \
    cd "/build/gcc-${GCC_VERSION}"; \
    ./contrib/download_prerequisites

RUN set -eux; \
    cd "/build/binutils-${BINUTILS_VERSION}"; \
    patch --dry-run -p0 < /patches/binutils-patch.diff; \
    patch -p0 < /patches/binutils-patch.diff

RUN set -eux; \
    cd "/build/gcc-${GCC_VERSION}"; \
    patch --dry-run -p0 < /patches/gcc-patch.diff; \
    patch -p0 < /patches/gcc-patch.diff; \
    grep -n "score-\\*-elf" gcc/config.gcc; \
    test -f gcc/config/score/score.cc; \
    grep -n "score-\\*-elf" libgcc/config.host

RUN set -eux; \
    cd "/build/newlib-${NEWLIB_VERSION}"; \
    patch --dry-run -p1 < /patches/newlib-patch.diff; \
    patch -p1 < /patches/newlib-patch.diff; \
    cd newlib; \
    [ -f configure.ac ] && autoreconf -fi

RUN set -eux; \
    mkdir -p /build/build-binutils; \
    cd /build/build-binutils; \
    ../binutils-${BINUTILS_VERSION}/configure \
        --target="${TARGET}" \
        --prefix="${PREFIX}" \
        --disable-nls \
        --disable-multilib \
        --disable-static; \
    make -j"$(nproc)"; \
    make install

RUN set -eux; \
    mkdir -p /build/build-gcc-stage1; \
    cd /build/build-gcc-stage1; \
    ../gcc-${GCC_VERSION}/configure \
        --target="${TARGET}" \
        --prefix="${PREFIX}" \
        --with-sysroot=${PREFIX}/${TARGET} \
        --without-headers \
        --with-newlib \
        --enable-obsolete \
        --disable-libada \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libssp \
        --disable-libatomic \
        --disable-libitm \
        --disable-libsanitizer \
        --disable-libquadmath \
        --disable-threads \
        --disable-multilib \
        --disable-target-zlib \
        --with-system-zlib \
        --disable-shared \
        --disable-nls \
        --disable-lto \
        --disable-libstdcxx-pch \
        --enable-languages=c,c++ \
        --with-gnu-as \
        --with-gnu-ld; \
    make -j"$(nproc)" all-gcc all-target-libgcc; \
    make install-gcc install-target-libgcc

RUN set -eux; \
    autoconf --version; \
    autoreconf --version; \
    rm -rf /build/build-newlib; \
    mkdir -p /build/build-newlib; \
    cd /build/build-newlib; \
    "/build/newlib-${NEWLIB_VERSION}/configure" \
        --target="${TARGET}" \
        --prefix="${PREFIX}" \
        --disable-multilib; \
    make -j"$(nproc)"; \
    make install; \
    strip --strip-unneeded ${PREFIX}/bin/* || true; \
    strip --strip-debug ${PREFIX}/${TARGET}/lib/*.a || true

FROM builder AS tester

COPY boards/score-elf.exp /usr/share/dejagnu/baseboards/score-elf.exp

RUN echo "set target_alias score-elf" > /usr/share/dejagnu/site.exp; \
    cp /usr/share/dejagnu/baseboards/score-elf.exp \
       /usr/share/dejagnu/baseboards/score-unknown-elf.exp;

RUN set -eux; \
    apk add --no-cache \
    dejagnu \
    expect \
    tcl;

WORKDIR /build/build-gcc-stage1

CMD ["sh", "-c", "make check-gcc RUNTESTFLAGS='--target_board=score-elf' && cp gcc/testsuite/gcc/gcc.sum /out/"]

FROM alpine:3.23.3 AS runtime-base

ENV PATH=/opt/score-toolchain/bin:/usr/local/bin:${PATH}

RUN apk add --no-cache \
    bash-completion \
    curl \
    ca-certificates \
    xz \
    bzip2 \
    gzip \
    tar \
    make \
    cmake \
    ninja-build \
    python3 \
    git \
    automake \
    file \
    rsync \
    vim \
    less

FROM runtime-base

COPY --from=builder /opt/score-toolchain /opt/score-toolchain

COPY bash-completion/score-elf-gcc.bash /etc/bash_completion.d/score-elf-gcc

WORKDIR /workspace
CMD ["/bin/bash"]
