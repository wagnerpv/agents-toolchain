#!/usr/bin/env bash
# slice.sh — fatia um arquivo grande em volumes de 5MB para versionar no git.
#
# Uso: scripts/slice.sh <arquivo> <nome-do-pacote>
#   <arquivo>        caminho do tar.xz / .deb / binário a fatiar
#   <nome-do-pacote> id do pacote no vendor (ex.: zig, chromium, firebird)
#
# Resultado: vendor/<nome>/<nome>.part.aa, .ab, ... (5MB cada) + atualiza o manifest
# com versão (derivada do nome do arquivo), sha256 do arquivo inteiro e contagem de partes.
#
# Este script roda LOCALMENTE quando se adiciona ou atualiza um toolchain. Os agentes em
# CI/sandbox usam só o restore.sh (nunca o slice.sh).
set -euo pipefail

VOLUME_SIZE="${VOLUME_SIZE:-5M}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 2 ]; then
  echo "uso: $0 <arquivo> <nome-do-pacote>" >&2
  exit 1
fi

SRC="$1"
NAME="$2"

[ -f "$SRC" ] || { echo "arquivo não encontrado: $SRC" >&2; exit 1; }

DEST="$ROOT/vendor/$NAME"
mkdir -p "$DEST"

# limpa volumes antigos do mesmo pacote (re-slice)
rm -f "$DEST/$NAME.part."* 2>/dev/null || true

echo "fatiando $SRC → $DEST/$NAME.part.* ($VOLUME_SIZE cada)"
split -b "$VOLUME_SIZE" -a 3 "$SRC" "$DEST/$NAME.part."

SHA="$(sha256sum "$SRC" | cut -d' ' -f1)"
PARTS="$(ls "$DEST/$NAME.part."* | wc -l | tr -d ' ')"
ORIG_NAME="$(basename "$SRC")"
SIZE="$(stat -c%s "$SRC")"

# grava o metadado do pacote (consumido pelo restore.sh)
cat > "$DEST/meta.env" <<META
PKG_NAME=$NAME
PKG_FILE=$ORIG_NAME
PKG_SHA256=$SHA
PKG_PARTS=$PARTS
PKG_SIZE=$SIZE
META

echo "  $PARTS volume(s), sha256=$SHA"
echo "  meta: $DEST/meta.env"
echo "feito. Lembre de commitar vendor/$NAME/."
