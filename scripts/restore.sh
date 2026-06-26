#!/bin/sh
# restore.sh — remonta um pacote vendorizado a partir dos volumes e verifica o sha256.
#
# Uso: scripts/restore.sh <nome-do-pacote> [destino]
#   <nome-do-pacote> id do pacote (ex.: zig, chromium, firebird)
#   [destino]        caminho de saída do arquivo remontado (default: /tmp/<arquivo-original>)
#
# Remonta vendor/<nome>/<nome>.part.* → arquivo original, confere o sha256 do manifesto e
# imprime o caminho do arquivo restaurado no stdout (última linha) para scripts consumirem.
#
# Este é o script que os agentes/CI usam. NÃO instala — só restaura o arquivo. A instalação
# fica no install.sh (que chama este).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "uso: $0 <nome-do-pacote> [destino]" >&2
  exit 1
fi

NAME="$1"
SRC="$ROOT/vendor/$NAME"

[ -d "$SRC" ] || { echo "pacote não vendorizado: $NAME (sem vendor/$NAME/)" >&2; exit 1; }
[ -f "$SRC/meta.env" ] || { echo "pacote sem meta.env: $NAME" >&2; exit 1; }

# shellcheck disable=SC1090
. "$SRC/meta.env"

DEST="${2:-/tmp/$PKG_FILE}"

echo "remontando $NAME ($PKG_PARTS volume(s)) → $DEST" >&2
cat "$SRC/$NAME.part."* > "$DEST"

GOT="$(sha256sum "$DEST" | cut -d' ' -f1)"
if [ "$GOT" != "$PKG_SHA256" ]; then
  echo "CHECKSUM FALHOU para $NAME" >&2
  echo "  esperado: $PKG_SHA256" >&2
  echo "  obtido:   $GOT" >&2
  rm -f "$DEST"
  exit 1
fi

echo "  sha256 OK ($GOT)" >&2
# última linha do stdout = caminho do arquivo restaurado (para o install.sh consumir)
echo "$DEST"
