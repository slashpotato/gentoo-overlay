FROM codeberg.org/slashpotato/overlay-builder
RUN emerge-webrsync -q
RUN emerge --sync -q
RUN emerge -uUDN --with-bdeps=y @world @preserved-rebuild
RUN eclean-pkg -d
RUN eclean-dist -df
