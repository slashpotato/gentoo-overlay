#!/usr/bin/env bash
# Синхронизирует llvm-core/llvm из ::gentoo, патчит каждый ебилд под bolt
# и раскладывает результат в нашем оверлее (llvm-core/llvm/).
#
# Переменные окружения:
#   GENTOO_TREE_URL  - откуда тянуть дерево (по умолчанию зеркало на github)
#   OVERLAY_DIR      - корень нашего оверлея (по умолчанию текущая директория)
#
# На выходе в stdout печатает список версий, которые были добавлены/изменены
# (по одной на строку), пусто - если изменений нет.

set -euo pipefail

GENTOO_TREE_URL="${GENTOO_TREE_URL:-https://github.com/gentoo/gentoo.git}"
OVERLAY_DIR="${OVERLAY_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

echo "== sparse-checkout llvm-core/llvm из ${GENTOO_TREE_URL} ==" >&2
git clone --depth=1 --filter=blob:none --sparse "${GENTOO_TREE_URL}" "${WORK}/gentoo" >&2
git -C "${WORK}/gentoo" sparse-checkout set llvm-core/llvm >&2

UPSTREAM_DIR="${WORK}/gentoo/llvm-core/llvm"
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
	rsync -a --delete "${UPSTREAM_DIR}/files/" "${OUR_DIR}/files/" >&2
fi

for f in "${changed[@]:-}"; do
	[[ -n "${f}" ]] && echo "${f}"
done
