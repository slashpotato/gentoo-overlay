EAPI=8

PYTHON_COMPAT=( python3_{10..14} )

inherit git-r3 python-any-r1 cmake

DESCRIPTION="Binary Optimization and Layout Tool (standalone build, tracks installed llvm-core/llvm)"
HOMEPAGE="https://github.com/llvm/llvm-project/tree/main/bolt https://llvm.org/"
EGIT_REPO_URI="https://github.com/llvm/llvm-project.git"
# EGIT_COMMIT выставляется динамически в pkg_setup, см. ниже.
# Можно принудительно переопределить через переменную окружения
# git-r3: EGIT_OVERRIDE_COMMIT_LLVM_BOLT=<tag-or-sha>

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS=""
IUSE="debug jemalloc test"
RESTRICT="!test? ( test )"

# := триггерит пересборку bolt при бампе subslot'а llvm-core/llvm/lld
# (т.е. при ABI-несовместимом обновлении LLVM). Для live-пакетов это
# работает настолько, насколько сам llvm-core/llvm-9999 меняет subslot
# между сборками — см. примечание в конце ответа.
RDEPEND="
	llvm-core/llvm:0=
	llvm-core/lld:0=
	jemalloc? ( dev-libs/jemalloc )
"
DEPEND="${RDEPEND}"
BDEPEND="
	${PYTHON_DEPS}
	dev-vcs/git
"

python_check_deps() {
	python_has_matching_uses "${RDEPEND}"
}

pkg_setup() {
	python-any-r1_pkg_setup

	# Определяем тег llvm-project, соответствующий установленному
	# llvm-core/llvm, и просим git-r3 зачекаутить именно его.
	local installed_llvm ver
	installed_llvm=$(best_version llvm-core/llvm)
	if [[ -z ${installed_llvm} ]]; then
		die "llvm-core/llvm must be installed before building ${PN}"
	fi

	ver=${installed_llvm#llvm-core/llvm-}
	ver=${ver%-r*}          # отбрасываем ревизию эбилда (-rN), если есть
	ver=${ver%_*}           # отбрасываем суффикс вроде _pre/_rc, если есть

	EGIT_COMMIT="llvmorg-${ver}"
	einfo "Building llvm-bolt against installed llvm-core/llvm-${ver} (tag ${EGIT_COMMIT})"
}

src_unpack() {
	git-r3_src_unpack
}

src_configure() {
	local llvm_dir lld_dir
	llvm_dir="$(llvm-config --cmakedir)"
	lld_dir="${llvm_dir/\/llvm//lld}"

	local mycmakeargs=(
		-DLLVM_DIR="${llvm_dir}"
		-DLLD_DIR="${lld_dir}"
		-DLLVM_MAIN_SRC_DIR="${S}/llvm"
		-DLLVM_TABLEGEN_EXE="$(type -P llvm-tblgen)"
		-DLLVM_INCLUDE_TESTS=$(usex test)
		-DLLVM_ENABLE_ASSERTIONS=$(usex debug)
		-DBOLT_ENABLE_RUNTIME=ON
		-DCMAKE_BUILD_TYPE=$(usex debug Debug Release)
	)

	use jemalloc && mycmakeargs+=( -DBOLT_USE_JEMALLOC=ON )

	CMAKE_USE_DIR="${S}/bolt" cmake_src_configure
}

src_test() {
	cmake_build check-bolt
}
