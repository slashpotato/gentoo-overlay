EAPI=8

inherit git-r3 meson

DESCRIPTION="Small C++ library for parsing LRC and eLRC files"
HOMEPAGE="https://slashpotato.codeberg.page/easyLRC/"
EGIT_REPO_URI="https://codeberg.org/slashpotato/easyLRC.git"
EGIT_BRANCH="master"

LICENSE="ZLIB"
SLOT="0"
KEYWORDS=""
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
		$(meson_use utils utils)
		-Dbuildtype=plain
	)
	meson_src_configure
}
