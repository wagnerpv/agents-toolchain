# Kakareja

Ferramentas de gravação de demos do sistema com overlay visual e trilha sonora.

**Reside em:** `scripts/kakareja/` [link](https://github.com/wagnerpv/agents-toolchain/tree/main/scripts/kakareja)

---

## Ferramentas

### record-demo

`scripts/kakareja/record-demo/record_demo.py` [link](https://github.com/wagnerpv/agents-toolchain/blob/main/scripts/kakareja/record-demo/record_demo.py)

Grava demo do sistema em `.webm` via Playwright (Python). Alvo original: `ssr-templates-engine`.

```bash
python3 scripts/kakareja/record-demo/record_demo.py \
  --repo /caminho/para/ssr-templates-engine \
  --port 3737
```

---

### overlay

`scripts/kakareja/overlay/` [link](https://github.com/wagnerpv/agents-toolchain/tree/main/scripts/kakareja/overlay)

Runner YAML em TypeScript/Bun. Injeta overlay no DOM durante a gravação — legendas, highlights, countdown, reações, end card e trilha sonora.

```bash
cd scripts/kakareja/overlay
bun install
bun run runner.ts roteiros/poc3-runner-yaml.yml
```
