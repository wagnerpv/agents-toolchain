# agents-toolchain

Toolchains **pinados e vendorizados** do ecossistema. Os binários (Zig, Bun, Chromium,
Firebird, Docker, gh, rsync, …) ficam versionados aqui, **fatiados em volumes de 5 MB** para o
git aceitar, com **checksum verificado** na remontagem.

## Por quê

Todo ambiente — sandbox, CI, máquina nova — re-baixava toolchains via `apt`/`curl` a cada vez:
lento, frágil e sujeito a sumiço de versão upstream. Aqui as versões são **pinadas** e os
binários **versionados**. `git clone` sempre funciona; download externo, não necessariamente.

**Objetivo: eliminar `apt` e `curl` por completo em todos os projetos.** Toda dependência de
toolchain vem daqui.

Repo separado de propósito: binários incham o `.git` para sempre (a história nunca esquece
blobs). Isolando aqui, os repos de código (delfweb-engine, etc.) ficam leves e só clonam o
toolchain quando precisam.

---

## Pré-requisitos

O `install.sh` **não baixa nada** — mas precisa de utilitários básicos para extrair e instalar:

- `bash`, `tar`, `unzip`, `sha256sum`, `find`, `dpkg` (este só para o Firebird).
- Permissão de escrita em `/opt/toolchain` e `/usr/local/bin` (na prática: **rodar como root**,
  como no sandbox e na imagem de CI). Para instalar sem root, veja as variáveis abaixo.

Esses utilitários vêm na base de qualquer Ubuntu/Debian mínimo — não são toolchain, são o
esqueleto do SO. O repo elimina o `apt`/`curl` **das dependências de projeto**, não do `coreutils`.

---

## Uso — instalar um toolchain

```sh
git clone https://github.com/wagnerpv/agents-toolchain
cd agents-toolchain

# um pacote:
sudo scripts/install.sh zig

# vários:
sudo scripts/install.sh zig bun chromium

# tudo que está vendorizado:
sudo scripts/install.sh all
```

`install.sh` para cada pacote: remonta os volumes → confere o sha256 → extrai/instala →
cria o symlink. Se o checksum não bater, aborta sem instalar.

### Em CI (exemplo GitHub Actions)

```yaml
- name: Toolchain (sem apt, sem curl)
  run: |
    git clone --depth 1 https://github.com/wagnerpv/agents-toolchain /tmp/tc
    /tmp/tc/scripts/install.sh zig chromium
```

### Variáveis de ambiente (opcionais)

| Variável | Default | Para quê |
|---|---|---|
| `TOOLCHAIN_PREFIX` | `/opt/toolchain` | onde os toolchains são extraídos |
| `TOOLCHAIN_BINDIR` | `/usr/local/bin` | onde os symlinks são criados (use um dir gravável p/ instalar sem root) |
| `PLAYWRIGHT_BROWSERS_PATH` | `/opt/pw-browsers` | destino do Chromium |
| `VOLUME_SIZE` | `5M` | tamanho do volume ao **fatiar** (slice.sh) |

Instalar sem root, por exemplo:
```sh
TOOLCHAIN_PREFIX=$HOME/.toolchain TOOLCHAIN_BINDIR=$HOME/.local/bin scripts/install.sh zig
```

---

## Estrutura

```
vendor/<pkg>/<pkg>.part.aaa, .aab, ...   volumes de 5 MB do arquivo original
vendor/<pkg>/meta.env                    versão, sha256, nº de partes, nome original
scripts/slice.sh                         fatia um arquivo em volumes  (uso LOCAL, ao adicionar/atualizar)
scripts/restore.sh                       remonta + verifica sha256 → imprime o caminho do arquivo
scripts/install.sh                       restore + instala (receita por pacote)
```

`restore.sh` é o tijolo: remonta e valida. `install.sh` chama o `restore.sh` e aplica a
**receita** do pacote (como extrair, onde colocar, qual symlink). Agentes/CI usam só
`install.sh` (ou `restore.sh`, se quiserem só o arquivo). `slice.sh` é exclusivo do mantenedor.

---

## Adicionar ou atualizar um toolchain

Duas etapas: (1) fatiar o arquivo oficial, (2) escrever a receita de instalação.

```sh
# 1. obtenha o arquivo oficial UMA vez (a única hora em que se baixa algo, na máquina do mantenedor)
#    ex.: zig-x86_64-linux-0.15.2.tar.xz, bun-linux-x64.zip, etc.

# 2. fatie em volumes + gere o meta.env (versão/sha256/partes):
scripts/slice.sh /caminho/zig-x86_64-linux-0.15.2.tar.xz zig

# 3. escreva a receita no scripts/install.sh — uma função install_<pkg>() que opera SÓ sobre
#    o arquivo restaurado (nunca baixa). Registre o case no dispatch install_one().
#    Exemplo (zig):
#      install_zig() {
#        local f; f="$(restore zig | tail -1)"
#        rm -rf "$PREFIX/zig"; mkdir -p "$PREFIX/zig"
#        tar xf "$f" -C "$PREFIX/zig" --strip-components=1
#        ln -sf "$PREFIX/zig/zig" "$BINDIR/zig"
#      }

# 4. commit (volumes + meta.env + receita):
git add vendor/zig scripts/install.sh README.md
git commit -m "vendor: zig 0.15.2"
git push
```

Para **atualizar a versão** de um pacote: rode o `slice.sh` de novo com o novo arquivo (ele
limpa os volumes antigos e regrava o `meta.env`), ajuste a versão na tabela abaixo, commit.

### Verificar a integridade sem instalar

```sh
scripts/restore.sh zig /tmp/zig.tar.xz   # remonta e confere o sha256; imprime o caminho
```

---

## Pacotes vendorizados

| Pacote | Versão | Origem | Receita |
|---|---|---|---|
| zig | 0.15.2 | ziglang.org (tar.xz) | extrai em `$TOOLCHAIN_PREFIX/zig`, symlink `zig` |
| bun | 1.1.38 | github oven-sh (zip) | extrai em `$TOOLCHAIN_PREFIX/bun`, symlink `bun` |
| chromium | build 1194 | Playwright (chromium+headless_shell+ffmpeg) | extrai em `$PLAYWRIGHT_BROWSERS_PATH` |
| firebird | 3.0.11 | Ubuntu noble (.deb x8) | `dpkg -i` server+core+common+utils+dev+libfbclient+libib-util+libtommath |
| docker | 27.4.1 | download.docker.com (static) | extrai em `$TOOLCHAIN_PREFIX/docker`, symlink dos binários |
| gh | 2.63.2 | github cli (tar.gz) | copia `gh` para `$TOOLCHAIN_BINDIR` |
| rsync | 3.2.7 | Ubuntu noble (.deb + libs) | `dpkg -i` rsync+libpopt+libxxhash+libzstd+liblz4 |

Todos com ciclo fatia→remonta→checksum provado, e install validado (zig/bun/gh/docker/chromium
instalam num prefix limpo; firebird/rsync via dpkg seguem o mesmo padrão do apt).
