#!/usr/bin/env bash
# Синхронизирует llvm-core/llvm из ::gentoo (через rsync-зеркало
# gentoo-portage, а не git clone — легче и не зависит от доступности github.com),
# патчит каждый ебилд под bolt и раскладывает результат в нашем оверлее.
#
# Переменные окружения:
#   GENTOO_RSYNC_URL - rsync-модуль/путь до llvm-core/llvm в зеркале portage
#                      (по умолчанию официальный round-robin rsync.gentoo.org)
#   OVERLAY_DIR      - корень нашего оверлея (по умолчанию текущая директория)
#
# На выходе в stdout печатает список версий, которые были добавлены/изменены
# (по одной на строку), пусто - если изменений нет.

set -euo pipefail

GENTOO_RSYNC_URL="${GENTOO_RSYNC_URL:-rsync://mirrors.dotsrc.org/gentoo-portage/llvm-core/llvm/}"
OVERLAY_DIR="${OVERLAY_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

echo "== rsync llvm-core/llvm из ${GENTOO_RSYNC_URL} ==" >&2
mkdir -p "${WORK}/upstream"
rsync --no-motd -a --timeout=60 "${GENTOO_RSYNC_URL}" "${WORK}/upstream/" >&2

UPSTREAM_DIR="${WORK}/upstream"
OUR_DIR="${OVERLAY_DIR}/llvm-core/llvm"
mkdir -p "${OUR_DIR}"

changed=()

shopt -s nullglob
for ebuild in "${UPSTREAM_DIR}"/*.ebuild; do
	name="$(basename "${ebuild}")"

	# live-ебилд (9999) пропускаем - версия там не привязана к релизу
	# и патчить его отдельным скриптом смысла нет, если вам не нужен
	# именно git-мастер с bolt; включайте вручную при необходимости.
	[[ "${name}" == *-9999.ebuild ]] && continue

	target="${OUR_DIR}/${name}"
	tmp_patched="${WORK}/${name}"

	python3 "${SCRIPT_DIR}/patch_llvm_bolt.py" "${ebuild}" "${tmp_patched}"

	if [[ -f "${target}" ]] && cmp -s "${tmp_patched}" "${target}"; then
		continue  # без изменений
	fi

	cp "${tmp_patched}" "${target}"
	changed+=("${name}")
done

# files/ каталог (патчи апстрима и т.п.) синкаем как есть, без модификаций
if [[ -d "${UPSTREAM_DIR}/files" ]]; then
	mkdir -p "${OUR_DIR}/files"
	rsync --no-motd -a --delete "${UPSTREAM_DIR}/files/" "${OUR_DIR}/files/" >&2
fi

for f in "${changed[@]:-}"; do
	[[ -n "${f}" ]] && echo "${f}"
done
