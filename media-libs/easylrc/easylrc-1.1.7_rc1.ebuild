EAPI=8

inherit bash-completion-r1 meson

DESCRIPTION="Small C++ library for parsing LRC and eLRC files"
HOMEPAGE="https://slashpotato.codeberg.page/easyLRC/"
SRC_URI="https://codeberg.org/slashpotato/easyLRC/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}"

LICENSE="ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+utils +bash-completion +zsh-completion +fish-completion"

RDEPEND="
	media-video/ffmpeg:=
	sys-apps/file
	bash-completion? ( app-shells/bash-completion )
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		$(meson_use utils utils)
		$(meson_use bash-completion install-bash-completion)
		$(meson_use zsh-completion install-zsh-completion)
		$(meson_use fish-completion install-fish-completion)
		-Dbuildtype=plain
	)

	use bash-completion && emesonargs+=(
		-Dbash-completion-dir="$(get_bashcompdir)"
	)
	use zsh-completion && emesonargs+=(
		-Dzsh-completion-dir="${EPREFIX}/usr/share/zsh/site-functions"
	)
	use fish-completion && emesonargs+=(
		-Dfish-completion-dir="${EPREFIX}/usr/share/fish/vendor_completions.d"
	)

	meson_src_configure
}
