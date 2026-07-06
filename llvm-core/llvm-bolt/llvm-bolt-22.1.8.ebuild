EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

LLVM_COMPONENTS=(
    llvm
    bolt
    cmake
)

inherit cmake llvm.org python-any-r1 toolchain-funcs

DESCRIPTION="LLVM BOLT post-link optimizer"
HOMEPAGE="https://llvm.org/"

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="${LLVM_MAJOR}"
KEYWORDS="~amd64 ~arm64 ~x86"

IUSE="debug"

llvm.org_set_globals

RDEPEND="
    virtual/zlib
"

DEPEND="${RDEPEND}"

BDEPEND="
    ${PYTHON_DEPS}
"

src_configure() {
    local mycmakeargs=(
        -DLLVM_ENABLE_PROJECTS=bolt

        -DCMAKE_BUILD_TYPE=Release

        -DLLVM_BUILD_TOOLS=OFF
        -DLLVM_BUILD_TESTS=OFF
        -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_INCLUDE_EXAMPLES=OFF
        -DLLVM_INCLUDE_DOCS=OFF
        -DLLVM_INCLUDE_BENCHMARKS=OFF

        -DLLVM_ENABLE_ASSERTIONS=$(usex debug)

        -DLLVM_ENABLE_ZLIB=FORCE_ON

        -DLLVM_BUILD_LLVM_DYLIB=ON
        -DLLVM_LINK_LLVM_DYLIB=ON

        -DLLVM_INSTALL_UTILS=ON

        -DCMAKE_INSTALL_PREFIX=/usr/lib/llvm/${LLVM_MAJOR}
    )

    cmake_src_configure
}

src_compile() {
    cmake_build llvm-bolt
    cmake_build llvm-bolt-diff
    cmake_build llvm-bolt-heatmap
    cmake_build merge-fdata
}

src_install() {
    DESTDIR="${D}" cmake_build install-llvm-bolt
    DESTDIR="${D}" cmake_build install-llvm-bolt-diff
    DESTDIR="${D}" cmake_build install-llvm-bolt-heatmap
    DESTDIR="${D}" cmake_build install-merge-fdata
}
