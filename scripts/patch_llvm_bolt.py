#!/usr/bin/env python3
"""
Патчит ебилд llvm-core/llvm из ::gentoo так, чтобы он умел собирать
BOLT как sibling-проект в том же дереве llvm-project (LLVM_ENABLE_PROJECTS=bolt),
под USE-флагом "bolt".

Использование:
    patch_llvm_bolt.py <path-to-upstream-ebuild> <path-to-output-ebuild>

Идемпотентен: если ебилд уже пропатчен, второй запуск ничего не ломает.
"""
import re
import sys
from pathlib import Path


def add_component(text: str) -> str:
	"""Добавляет 'bolt' в массив LLVM_COMPONENTS, если его там нет."""
	m = re.search(r"LLVM_COMPONENTS=\(([^)]*)\)", text, re.S)
	if not m:
		raise SystemExit("не нашёл LLVM_COMPONENTS=( ... ) в ебилде")

	items = m.group(1).split()
	if "bolt" in items:
		return text  # уже пропатчено

	items.append("bolt")
	new_array = "LLVM_COMPONENTS=( " + " ".join(items) + " )"
	return text[: m.start()] + new_array + text[m.end():]


def add_iuse(text: str) -> str:
	"""Добавляет 'bolt' в IUSE (в виде опционального +bolt), если его там нет."""
	m = re.search(r'^IUSE="([^"]*)"', text, re.M)
	if not m:
		raise SystemExit("не нашёл IUSE=\"...\" в ебилде")

	if re.search(r"(^|[\s+])bolt($|\s)", m.group(1)):
		return text  # уже есть

	new_iuse = f'IUSE="{m.group(1).rstrip()} bolt"'
	return text[: m.start()] + new_iuse + text[m.end():]


def add_cmake_arg(text: str) -> str:
	"""
	Добавляет в src_configure() строку с условным
	-DLLVM_ENABLE_PROJECTS=bolt, если такой строки ещё нет.
	Ищем mycmakeargs=( ... ) и вставляем перед закрывающей скобкой.
	"""
	if "LLVM_ENABLE_PROJECTS=bolt" in text:
		return text  # уже пропатчено

	m = re.search(r"(mycmakeargs=\(\n)(.*?)(\n\t\))", text, re.S)
	if not m:
		raise SystemExit("не нашёл mycmakeargs=( ... ) в src_configure()")

	insertion = '\t\t$(usex bolt -DLLVM_ENABLE_PROJECTS=bolt "")\n'
	patched = m.group(1) + m.group(2) + "\n" + insertion.rstrip("\n") + m.group(3)
	return text[: m.start()] + patched + text[m.end():]


def add_bdepend(text: str) -> str:
	"""
	Добавляет test? ( llvm-core/clang llvm-core/lld ) в BDEPEND - это
	только бинарники для тестового сьюта BOLT, не для сборки самого bolt.
	Если BDEPEND в ебилде нет вообще - создаёт его сразу после IUSE.
	"""
	needed_line = "\ttest? ( llvm-core/clang llvm-core/lld )\n"

	m = re.search(r'^BDEPEND="(.*?)"\n', text, re.S | re.M)
	if m:
		if "llvm-core/clang" in m.group(1) and "llvm-core/lld" in m.group(1):
			return text  # уже пропатчено
		inner = m.group(1)
		if inner and not inner.endswith("\n"):
			inner += "\n"
		new_block = f'BDEPEND="{inner}{needed_line}"\n'
		return text[: m.start()] + new_block + text[m.end():]

	m_iuse = re.search(r'^IUSE="[^"]*"\n', text, re.M)
	if not m_iuse:
		raise SystemExit("не нашёл ни BDEPEND, ни IUSE, чтобы вставить BDEPEND")
	new_block = f'BDEPEND="\n{needed_line}"\n'
	return text[: m_iuse.end()] + new_block + text[m_iuse.end():]


def add_bolt_test_toolchain(text: str) -> str:
	"""
	После mycmakeargs=( ... ) добавляет условный блок: если USE=bolt test
	и в системе реально стоят llvm-core/clang + llvm-core/lld - передаёт
	BOLT_CLANG_EXE/BOLT_LLD_EXE, чтобы BOLT увидел их и не писал
	"Not including BOLT tests since clang or lld is disabled".
	LLVM_ENABLE_PROJECTS не трогаем - clang/lld остаются отдельными пакетами,
	а не пересобираются заново внутри этого ебилда.
	"""
	if "BOLT_CLANG_EXE" in text:
		return text  # уже пропатчено

	block = (
		"\n\tif use bolt && use test \\\n"
		"\t\t&& has_version llvm-core/clang && has_version llvm-core/lld; then\n"
		"\t\tmycmakeargs+=(\n"
		'\t\t\t-DBOLT_CLANG_EXE="$(type -P clang)"\n'
		'\t\t\t-DBOLT_LLD_EXE="$(type -P ld.lld)"\n'
		"\t\t)\n"
		"\tfi\n\n"
	)

	m = re.search(r"mycmakeargs=\(\n.*?\n\t\)\n", text, re.S)
	if not m:
		raise SystemExit("не нашёл конец mycmakeargs=( ... ) для вставки блока bolt/test")

	insert_pos = m.end()
	return text[:insert_pos] + block + text[insert_pos:]


def add_distribution_components(text: str) -> str:
	"""
	Добавляет use bolt && out+=( ... ) в get_distribution_components(),
	рядом с существующими use binutils-plugin/debuginfod/xml && out+=(...).
	Без этого сборка падает с die "Update get_distribution_components()!",
	т.к. включение bolt в LLVM_ENABLE_PROJECTS добавляет CMake-компоненты,
	которых ручной список out[] ещё не знает.
	"""
	if "llvm-bolt-heatmap" in text:
		return text  # уже пропатчено

	anchor = '\tfi\n\tprintf "%s${sep}" "${out[@]}"\n}\n'
	if anchor not in text:
		raise SystemExit(
			"не нашёл хвост get_distribution_components() "
			"(ожидал '\\tfi\\n\\tprintf \"%s${sep}\" \"${out[@]}\"\\n}\\n')"
		)

	block = (
		"\t\tuse bolt && out+=(\n"
		"\t\t\tbolt\n"
		"\t\t\tbolt_rt\n"
		"\t\t\tllvm-bolt-binary-analysis\n"
		"\t\t\tllvm-bolt-heatmap\n"
		"\t\t\tllvm-bolt\n"
		"\t\t\tmerge-fdata\n"
		"\t\t)\n"
	)

	return text.replace(anchor, block + anchor, 1)


def add_marker(text: str) -> str:
	"""Комментарий-маркер сверху файла, чтобы было видно, что это не ванильный ебилд."""
	marker = (
		"# ------------------------------------------------------------------\n"
		"# Patched by slashpotato/gentoo-overlay: adds bolt to LLVM_COMPONENTS\n"
		"# and a conditional -DLLVM_ENABLE_PROJECTS=bolt behind USE=bolt.\n"
		"# Do not edit by hand — regenerated by .forgejo/workflows/sync-llvm-bolt.yml\n"
		"# ------------------------------------------------------------------\n"
	)
	if marker in text:
		return text
	# EAPI должна остаться первой значимой строкой ебилда, так что маркер после неё
	lines = text.splitlines(keepends=True)
	for i, line in enumerate(lines):
		if line.startswith("EAPI="):
			lines.insert(i + 1, "\n" + marker)
			break
	else:
		lines.insert(0, marker)
	return "".join(lines)


def main() -> None:
	if len(sys.argv) != 3:
		print(__doc__)
		sys.exit(1)

	src, dst = Path(sys.argv[1]), Path(sys.argv[2])
	text = src.read_text()

	text = add_component(text)
	text = add_iuse(text)
	text = add_cmake_arg(text)
	text = add_bdepend(text)
	text = add_bolt_test_toolchain(text)
	text = add_distribution_components(text)
	text = add_marker(text)

	dst.parent.mkdir(parents=True, exist_ok=True)
	dst.write_text(text)
	print(f"OK: {src} -> {dst}")


if __name__ == "__main__":
	main()
