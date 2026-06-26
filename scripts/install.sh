#!/usr/bin/env bash
# install.sh — remonta e INSTALA um ou mais pacotes do toolchain. Sem apt, sem curl.
#
# Uso:
#   scripts/install.sh <pacote> [<pacote> ...]   instala os pacotes nomeados
#   scripts/install.sh all                        instala tudo que está vendorizado
#
# Cada pacote tem uma "receita" de instalação abaixo (como extrair/onde colocar/symlink).
# A receita NUNCA baixa nada — opera só sobre o arquivo restaurado de vendor/.
#
# Objetivo do repo: eliminar apt e curl em todos os projetos. Toda dependência de toolchain
# vem daqui, com versão pinada e checksum verificado.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${TOOLCHAIN_PREFIX:-/opt/toolchain}"
BINDIR="${TOOLCHAIN_BINDIR:-/usr/local/bin}"

restore() { "$ROOT/scripts/restore.sh" "$1"; }

install_zig() {
  local f; f="$(restore zig | tail -1)"
  rm -rf "$PREFIX/zig"
  mkdir -p "$PREFIX/zig"
  tar xf "$f" -C "$PREFIX/zig" --strip-components=1
  ln -sf "$PREFIX/zig/zig" "$BINDIR/zig"
  echo "zig: $("$BINDIR/zig" version)"
}

install_bun() {
  local f; f="$(restore bun | tail -1)"
  rm -rf "$PREFIX/bun"
  mkdir -p "$PREFIX/bun"
  # bun é distribuído como .zip com o binário dentro
  unzip -oq "$f" -d "$PREFIX/bun"
  local bin; bin="$(find "$PREFIX/bun" -name bun -type f | head -1)"
  ln -sf "$bin" "$BINDIR/bun"
  echo "bun: $("$BINDIR/bun" --version)"
}

install_chromium() {
  local f; f="$(restore chromium | tail -1)"
  mkdir -p "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
  tar xf "$f" -C "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
  echo "chromium: extraído em ${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
}

install_firebird() {
  # .deb(s) do firebird server + dev + libfbclient — instala via dpkg (não apt, não baixa nada)
  local f; f="$(restore firebird | tail -1)"
  local tmp; tmp="$(mktemp -d)"
  tar xf "$f" -C "$tmp"
  dpkg -i "$tmp"/*.deb || true   # resolve ordem de deps entre os .deb locais
  echo "firebird: .deb(s) instalados"
}

install_docker()  { local f; f="$(restore docker | tail -1)"; rm -rf "$PREFIX/docker"; mkdir -p "$PREFIX"; tar xf "$f" -C "$PREFIX"; ln -sf "$PREFIX"/docker/* "$BINDIR/"; echo "docker: $("$BINDIR/docker" --version 2>/dev/null || echo instalado)"; }
install_gh()      { local f; f="$(restore gh | tail -1)";      local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; cp "$(find "$t" -name gh -type f | head -1)" "$BINDIR/gh"; chmod +x "$BINDIR/gh"; echo "gh: $("$BINDIR/gh" --version | head -1)"; }
# rsync vem como .deb(s) (binário + libs) — instala via dpkg, igual ao firebird.
install_rsync()   { local f; f="$(restore rsync | tail -1)"; local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; dpkg -i "$t"/*.deb || true; echo "rsync: $(rsync --version | head -1)"; }
install_nats()    { local f; f="$(restore nats | tail -1)";   local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; cp "$(find "$t" -name nats-server -type f | head -1)" "$BINDIR/nats-server"; chmod +x "$BINDIR/nats-server"; echo "nats-server: $("$BINDIR/nats-server" -v)"; }

install_one() {
  case "$1" in
    zig)       install_zig ;;
    bun)       install_bun ;;
    chromium)  install_chromium ;;
    firebird)  install_firebird ;;
    docker)    install_docker ;;
    gh)        install_gh ;;
    rsync)     install_rsync ;;
    nats)      install_nats ;;
    *) echo "receita desconhecida: $1" >&2; return 1 ;;
  esac
}

[ $# -ge 1 ] || { echo "uso: $0 <pacote>... | all" >&2; exit 1; }

if [ "$1" = "all" ]; then
  for d in "$ROOT"/vendor/*/; do
    [ -f "$d/meta.env" ] || continue
    install_one "$(basename "$d")"
  done
else
  for p in "$@"; do install_one "$p"; done
fi
