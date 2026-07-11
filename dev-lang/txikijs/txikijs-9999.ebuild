EAPI=8

inherit cmake git-r3

DESCRIPTION="A tiny JavaScript runtime built on QuickJS-ng and libuv"
HOMEPAGE="https://txikijs.org https://github.com/saghul/txiki.js"

EGIT_REPO_URI="https://github.com/saghul/txiki.js.git"
EGIT_SUBMODULES=( '*' )

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
IUSE="debug sqlite test wasm"

RDEPEND="dev-libs/libffi:="
DEPEND="${RDEPEND}"
BDEPEND="
	sys-devel/autoconf
	sys-devel/libtool
	sys-devel/gettext
	virtual/pkgconfig
"

PROPERTIES="live"
RESTRICT="!test? ( test )"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=$(usex debug Debug Release)
		-DBUILD_WITH_MIMALLOC=$(usex debug OFF ON)
		-DTJS__WASM=$(usex wasm ON OFF)
		-DTJS__SQLITE=$(usex sqlite ON OFF)
	)
	cmake_src_configure
}

src_test() {
	cmake_build test
}

src_install() {
	cmake_src_install

	if [[ -d "${S}/examples" ]] ; then
		docinto examples
		dodoc -r "${S}"/examples/.
	fi
}
