EAPI=8

inherit meson

DESCRIPTION="Small C++ library for parsing LRC and eLRC files"
HOMEPAGE="https://slashpotato.codeberg.page/easyLRC/"

SRC_URI="https://codeberg.org/slashpotato/easyLRC/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}"

LICENSE="ZLIB"
SLOT="0"
KEYWORDS="amd64 arm64"
IUSE="+utils"

RDEPEND="
	media-video/ffmpeg:=
	sys-apps/file
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		#$(meson_use utils utils)
		-Dbuildtype=plain
	)
	meson_src_configure
}

src_install() {
	meson_src_install
}
