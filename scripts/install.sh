#!/bin/sh
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
set -eu

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
  # bunx é o próprio bun invocado com outro nome (alias) — cria o symlink.
  ln -sf "$bin" "$BINDIR/bunx"
  echo "bun: $("$BINDIR/bun" --version)  (bunx: alias)"
}

install_chromium() {
  local f; f="$(restore chromium | tail -1)"
  mkdir -p "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
  tar xf "$f" -C "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
  echo "chromium: extraído em ${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
}

install_firebird5_server() {
  # SERVIDOR Firebird 5 completo (SuperServer) extraído em /opt/firebird5.
  # O tarball inclui libtomcrypt.so.1 (dep runtime do binário) para evitar apt no CI.
  # É o servidor que ensure-fb.sh do delfweb-engine espera em /opt/firebird5/bin/firebird,
  # para rodar make e2e / make aa-audit em ambiente de agente SEM Docker.
  local f; f="$(restore firebird5-server | tail -1)"
  rm -rf /opt/firebird5
  mkdir -p /opt
  tar xzf "$f" -C /opt   # o tarball já contém firebird5/ na raiz → vira /opt/firebird5
  cp -a /opt/firebird5/lib/libfbclient.so*  /usr/local/lib/ 2>/dev/null || true
  cp -a /opt/firebird5/lib/libib_util.so*   /usr/local/lib/ 2>/dev/null || true
  cp -a /opt/firebird5/lib/libtomcrypt.so*  /usr/local/lib/ 2>/dev/null || true
  ldconfig 2>/dev/null || true
  echo "firebird5-server: instalado em /opt/firebird5"
  echo "  servidor: /opt/firebird5/bin/firebird (use FIREBIRD_BIN=/opt/firebird5/bin/firebird)"
}

install_docker()  { local f; f="$(restore docker | tail -1)"; rm -rf "$PREFIX/docker"; mkdir -p "$PREFIX"; tar xf "$f" -C "$PREFIX"; ln -sf "$PREFIX"/docker/* "$BINDIR/"; echo "docker: $("$BINDIR/docker" --version 2>/dev/null || echo instalado)"; }
install_gh()      { local f; f="$(restore gh | tail -1)";      local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; cp "$(find "$t" -name gh -type f | head -1)" "$BINDIR/gh"; chmod +x "$BINDIR/gh"; echo "gh: $("$BINDIR/gh" --version | head -1)"; }
# rsync vem como .deb(s) (binário + libs) — instala via dpkg, igual ao firebird.
install_rsync()   { local f; f="$(restore rsync | tail -1)"; local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; dpkg -i "$t"/*.deb || true; echo "rsync: $(rsync --version | head -1)"; }
install_nats()    { local f; f="$(restore nats | tail -1)";   local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; cp "$(find "$t" -name nats-server -type f | head -1)" "$BINDIR/nats-server"; chmod +x "$BINDIR/nats-server"; echo "nats-server: $("$BINDIR/nats-server" -v)"; }
install_jq()      { local f; f="$(restore jq | tail -1)";     local t; t="$(mktemp -d)"; tar xf "$f" -C "$t"; cp "$(find "$t" -name jq -type f | head -1)" "$BINDIR/jq"; chmod +x "$BINDIR/jq"; echo "jq: $("$BINDIR/jq" --version)"; }
install_typst()   { local f; f="$(restore typst | tail -1)";  local t; t="$(mktemp -d)"; tar xf "$f" -C "$t" --strip-components=1; cp "$t/typst" "$BINDIR/typst"; chmod +x "$BINDIR/typst"; echo "typst: $("$BINDIR/typst" --version)"; }
install_firebird5_client() {
  # CLIENTE Firebird 5 (libfbclient + libtommath + headers + firebird.msg) para o LINK do engine.
  # O tarball inclui libtommath.so.1 (dep runtime do fbclient) para evitar apt no CI/sandbox.
  # O servidor FB5 vem do container, não daqui.
  local f; f="$(restore firebird5-client | tail -1)"
  local dst="$PREFIX/firebird5-client"
  rm -rf "$dst"; mkdir -p "$dst"
  tar xzf "$f" -C "$dst"
  # symlinks das libs num path padrão de linker
  cp -a "$dst"/lib/libfbclient.so* /usr/local/lib/ 2>/dev/null || true
  cp -a "$dst"/lib/libtommath.so* /usr/local/lib/ 2>/dev/null || true
  ldconfig 2>/dev/null || true
  echo "firebird5-client: instalado em $dst"
  echo "  para compilar: export FIREBIRD_INCLUDE=$dst/include FIREBIRD_LIB=$dst/lib"
  echo "  libfbclient: $(ls "$dst"/lib/libfbclient.so.5* 2>/dev/null | head -1)"
}

install_one() {
  case "$1" in
    zig)       install_zig ;;
    bun)       install_bun ;;
    chromium)  install_chromium ;;
    firebird5-server) install_firebird5_server ;;
    firebird5-client) install_firebird5_client ;;
    docker)    install_docker ;;
    gh)        install_gh ;;
    rsync)     install_rsync ;;
    nats)      install_nats ;;
    jq)        install_jq ;;
    typst)     install_typst ;;
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
