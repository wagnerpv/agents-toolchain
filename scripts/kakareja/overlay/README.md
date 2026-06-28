# Kakareja — Overlay

Grava demos do sistema com overlay visual (legendas, highlights, reações, countdown) e trilha sonora.

## Uso

```bash
bun install
bun run demo              # roda demo-pesquisa.yml
bun run runner.ts roteiro.yml  # roda qualquer roteiro
```

## Estrutura

- `runner.ts` — runner que lê o roteiro YAML e executa via Playwright
- `primitives.ts` — funções de overlay (introModal, caption, highlight, clickAnim, reaction)
- `demo-pesquisa.yml` — roteiro de exemplo
- `demo.html` — página HTML de exemplo (substitua pela URL real da aplicação)

## Assets de áudio

Colocar em `assets/`:
- `looney-tunes-theme.mp3` — música de fundo durante a demo
- `looney-tunes-thats-all-folks.mp3` — encerramento sincronizado com o end card

## Formato do roteiro

```yaml
demo:
  title: "Título da demo"
  page: "caminho/para/demo.html"   # ou URL HTTP
  out: "/tmp/saida"

steps:
  - intro:
      lines:
        - "Descrição do que vai acontecer."
  - caption: "Legenda na tela..."
  - highlight: "#seletor-css"
  - wait: 1000
  - type:
      target: "#input"
      text: "texto a digitar"
  - click: "#botao"
  - reaction: "😎"
  - clear_caption
```
