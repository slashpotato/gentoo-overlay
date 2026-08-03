FROM docker.io/gentoo/stage3:latest
RUN emerge-webrsync -q || emerge --sync -q
RUN echo 'FEATURES="${FEATURES} parallel-fetch parallel-install"' >> /etc/portage/make.conf
RUN emerge -qg net-libs/nodejs dev-vcs/git dev-util/pkgcheck
