# agents-toolchain

Toolchains **pinados e vendorizados** do ecossistema. Os binários (Zig, Bun, Chromium,
Firebird, Docker, gh, rsync, …) ficam versionados aqui, **fatiados em volumes de 5MB** para o
git aceitar, com checksum verificado na remontagem.

## Por quê

Todo ambiente — sandbox, CI, máquina nova — re-baixava toolchains via `apt`/`curl` a cada vez:
lento, frágil, e sujeito a sumiço de versão upstream. Aqui as versões são **pinadas** e os
binários **versionados**. `git clone` sempre funciona; download externo, não necessariamente.

**Objetivo: eliminar `apt` e `curl` por completo em todos os projetos.** Toda dependência de
toolchain vem daqui.

Por que repo separado: binários incham o `.git` para sempre (a história nunca esquece blobs).
Isolando aqui, os repos de código (delfweb-engine, etc.) ficam leves e clonam o toolchain quando
precisam.

## Uso (em qualquer projeto / CI / sandbox)

```sh
git clone https://github.com/wagnerpv/agents-toolchain
# instala um toolchain (remonta volumes + verifica sha256 + instala — sem apt, sem curl):
agents-toolchain/scripts/install.sh zig
# ou tudo de uma vez:
agents-toolchain/scripts/install.sh all
```

## Estrutura

```
vendor/<pkg>/<pkg>.part.aaa, .aab, ...   volumes de 5MB do arquivo original
vendor/<pkg>/meta.env                    versão, sha256, nº de partes, nome original
scripts/slice.sh                         fatia um arquivo em volumes (uso LOCAL, ao adicionar/atualizar)
scripts/restore.sh                       remonta + verifica sha256 → caminho do arquivo
scripts/install.sh                       restore + instala (receita por pacote)
```

## Adicionar ou atualizar um toolchain (uso local)

```sh
# 1. obtenha o arquivo oficial UMA vez (a única hora em que se baixa algo)
# 2. fatie:
scripts/slice.sh /caminho/zig-x86_64-linux-0.15.2.tar.xz zig
# 3. commit:
git add vendor/zig && git commit -m "vendor: zig 0.15.2"
```

A receita de instalação de cada pacote vive em `scripts/install.sh` (como extrair, onde colocar,
qual symlink criar). Pacote novo = volumes + meta.env + uma função `install_<pkg>` na receita.

## Pacotes

| Pacote | Versão | Receita |
|---|---|---|
| zig | 0.15.2 | extrai em /opt/toolchain/zig, symlink /usr/local/bin/zig |
