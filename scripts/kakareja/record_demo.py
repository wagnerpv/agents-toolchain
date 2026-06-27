"""
record_demo.py — Kakareja: grava demo do sistema em .webm

Sistema alvo: ssr-templates-engine (@eco00/ssr-server)
Viewport: mobile (390x844 — iPhone 14)

Pré-requisitos:
  pip install playwright --break-system-packages
  # Chromium via agents-toolchain (sem download):
  PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers agents-toolchain/scripts/install.sh chromium
  # OU instalar direto:
  playwright install chromium

Uso:
  python3 agents-toolchain/scripts/kakareja/record_demo.py \
    --repo /caminho/para/ssr-templates-engine \
    --port 3737
"""

import subprocess, time, os, sys, argparse
from pathlib import Path
from playwright.sync_api import sync_playwright

BUN = os.path.expanduser("~/.bun/bin/bun")


def wait_for_server(url, timeout=20):
    import urllib.request
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(url, timeout=1)
            return True
        except Exception:
            time.sleep(0.3)
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=str(Path.home() / "ssr-templates-engine"))
    parser.add_argument("--port", type=int, default=3737)
    parser.add_argument("--out", default="videos")
    parser.add_argument("--seed", default="default")
    args = parser.parse_args()

    repo = Path(args.repo)
    video_dir = Path(args.out)
    video_dir.mkdir(exist_ok=True)
    base_url = f"http://localhost:{args.port}"
    server_entry = repo / "packages/@eco00/ssr-server/src/server.js"

    print(f"[kakareja] Subindo server em {base_url} (seed: {args.seed})")
    server = subprocess.Popen(
        [BUN, str(server_entry), "--port", str(args.port), "--seed", args.seed],
        cwd=str(repo),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        if not wait_for_server(base_url):
            print("[kakareja] Server não respondeu.")
            server.terminate()
            sys.exit(1)
        print("[kakareja] Server pronto.")

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            context = browser.new_context(
                record_video_dir=str(video_dir),
                record_video_size={"width": 390, "height": 844},
                viewport={"width": 390, "height": 844},
                device_scale_factor=2,
                is_mobile=True,
            )
            page = context.new_page()

            # Index — lista de módulos
            print("[kakareja] / — lista de módulos")
            page.goto(base_url)
            page.wait_for_load_state("networkidle")
            time.sleep(2)

            # Categorias
            print("[kakareja] /categorias")
            page.goto(f"{base_url}/categorias")
            page.wait_for_load_state("networkidle")
            time.sleep(2.5)

            # Produtos
            print("[kakareja] /produtos")
            page.goto(f"{base_url}/produtos")
            page.wait_for_load_state("networkidle")
            time.sleep(2.5)

            # Pedidos
            print("[kakareja] /pedidos")
            page.goto(f"{base_url}/pedidos")
            page.wait_for_load_state("networkidle")
            time.sleep(2.5)

            # Fragmento SSE
            print("[kakareja] /categorias/fragmento/grid-categorias")
            page.goto(f"{base_url}/categorias/fragmento/grid-categorias")
            page.wait_for_load_state("networkidle")
            time.sleep(2)

            context.close()
            browser.close()

        videos = sorted(video_dir.glob("*.webm"), key=lambda f: f.stat().st_mtime)
        if videos:
            final = video_dir / "demo-ssr-templates-engine.webm"
            videos[-1].rename(final)
            print(f"[kakareja] Vídeo: {final} ({final.stat().st_size // 1024}KB)")
        else:
            print("[kakareja] Nenhum vídeo gerado.")

    finally:
        server.terminate()
        server.wait()
        print("[kakareja] Server encerrado.")


if __name__ == "__main__":
    main()
