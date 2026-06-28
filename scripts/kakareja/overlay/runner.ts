/**
 * POC 3 — Runner YAML
 * Lê um roteiro .yml e executa a demo via Playwright.
 * Uso: bun run runner.ts demo-pesquisa.yml
 */
import { chromium, type Page, type BrowserContext } from 'playwright';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'fs';

// ── YAML parser minimalista (sem dependência) ────────────────────────────────

function parseYaml(src: string): any {
  // Delega para bun/node eval seguro via JSON intermediário
  // Em produção: usar bun add yaml
  const lines = src.split('\n');
  // Usa o yaml nativo do bun se disponível, senão fallback simples
  try {
    // @ts-ignore
    return Bun.parseYaml(src);
  } catch {
    throw new Error('Instalar yaml: bun add yaml');
  }
}

// ── Primitivas de overlay ────────────────────────────────────────────────────

async function introModal(page: Page, lines: string[]): Promise<void> {
  await page.evaluate((ls: string[]) => {
    const o = document.createElement('div');
    o.id = '__nina_intro';
    o.style.cssText = 'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:Arial,sans-serif;gap:16px;';
    const desc = ls.map(l => `<p style="color:#e0e0e0;font-size:20px;text-align:center;max-width:700px;line-height:1.5;margin:0">${l}</p>`).join('');
    o.innerHTML = `${desc}<div id="__nina_cd" style="color:#ff6600;font-size:120px;font-weight:900;line-height:1;margin-top:32px">3</div>`;
    document.body.appendChild(o);
  }, lines);

  for (const n of ['2', '1']) {
    await page.waitForTimeout(1000);
    await page.evaluate((v: string) => { const el = document.getElementById('__nina_cd'); if (el) el.innerText = v; }, n);
  }
  await page.waitForTimeout(1000);
  await page.evaluate(() => {
    const el = document.getElementById('__nina_intro') as HTMLElement | null;
    if (!el) return;
    el.style.transition = 'opacity 0.5s ease';
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 550);
  });
  await page.waitForTimeout(600);
}

async function caption(page: Page, text: string): Promise<void> {
  await page.evaluate((t: string) => {
    let el = document.getElementById('__nina_caption') as HTMLElement | null;
    if (!el) {
      el = document.createElement('div');
      el.id = '__nina_caption';
      el.style.cssText = 'position:fixed;bottom:0;left:0;right:0;background:rgba(0,0,0,0.75);color:white;font-size:18px;font-family:Arial,sans-serif;padding:14px 24px;z-index:99998;text-align:center;letter-spacing:0.3px;';
      document.body.appendChild(el);
    }
    el.style.display = 'block';
    el.innerText = t;
  }, text);
}

async function clearCaption(page: Page): Promise<void> {
  await page.evaluate(() => { const el = document.getElementById('__nina_caption') as HTMLElement | null; if (el) el.style.display = 'none'; });
}

async function highlight(page: Page, selector: string): Promise<void> {
  await page.evaluate((sel: string) => {
    const el = document.querySelector(sel) as HTMLElement | null;
    if (!el) return;
    el.style.outline = '3px solid #ff6600';
    el.style.boxShadow = '0 0 14px rgba(255,102,0,0.8)';
    setTimeout(() => { el.style.outline = ''; el.style.boxShadow = ''; }, 2000);
  }, selector);
  await page.waitForTimeout(400);
}

async function clickAnim(page: Page, selector: string): Promise<void> {
  const box = await page.locator(selector).boundingBox();
  if (!box) return;
  const cx = box.x + box.width / 2, cy = box.y + box.height / 2;
  await page.evaluate(({ x, y }: { x: number; y: number }) => {
    const d = document.createElement('div');
    d.style.cssText = `position:fixed;width:40px;height:40px;background:rgba(255,102,0,0.85);border-radius:50%;left:${x - 20}px;top:${y - 20}px;z-index:99997;pointer-events:none;animation:nina-pop 0.5s ease-out forwards;`;
    const s = document.createElement('style');
    s.textContent = '@keyframes nina-pop{0%{transform:scale(0.5);opacity:1}100%{transform:scale(2.5);opacity:0}}';
    document.head.appendChild(s);
    document.body.appendChild(d);
    setTimeout(() => d.remove(), 600);
  }, { x: cx, y: cy });
  await page.waitForTimeout(300);
}

async function reaction(page: Page, emoji: string): Promise<void> {
  await page.evaluate((e: string) => {
    const el = document.createElement('div');
    el.style.cssText = `
      position:fixed;inset:0;z-index:99996;
      display:flex;align-items:center;justify-content:center;
      pointer-events:none;
      font-size:220px;
      opacity:0;
      animation:nina-reaction 1.8s ease-in-out forwards;
    `;
    el.innerText = e;
    const s = document.createElement('style');
    s.textContent = '@keyframes nina-reaction{0%{opacity:0;transform:scale(0.5)}30%{opacity:0.85;transform:scale(1.1)}70%{opacity:0.85;transform:scale(1)}100%{opacity:0;transform:scale(0.9)}}';
    document.head.appendChild(s);
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 1900);
  }, emoji);
  await page.waitForTimeout(1900);
}

// ── Runner ───────────────────────────────────────────────────────────────────

const __dir = dirname(fileURLToPath(import.meta.url));
const roteiro = readFileSync(join(__dir, process.argv[2] || 'demo-pesquisa.yml'), 'utf8');
const cfg = parseYaml(roteiro);

const demoUrl = `file://${resolve(__dir, cfg.demo.page)}`;
const outDir = cfg.demo.out || '/tmp/poc3-out';
const assets = resolve(__dir, '../poc1/assets');

mkdirSync(outDir, { recursive: true });
mkdirSync('/tmp/poc3-end-out', { recursive: true });

const browser = await chromium.launch({ headless: true });

// Gravar demo
const ctx: BrowserContext = await browser.newContext({
  recordVideo: { dir: outDir, size: { width: 1280, height: 720 } },
  viewport: { width: 1280, height: 720 },
});
const page: Page = await ctx.newPage();
await page.goto(demoUrl);
await page.waitForTimeout(400);

// Executar steps do roteiro
for (const step of cfg.steps) {
  if (step.intro)        await introModal(page, step.intro.lines);
  else if (step.caption) await caption(page, step.caption);
  else if (step === 'clear_caption' || (typeof step === 'object' && 'clear_caption' in step)) await clearCaption(page);
  else if (step.highlight) await highlight(page, step.highlight);
  else if (step.wait)    await page.waitForTimeout(step.wait);
  else if (step.type)    await page.fill(step.type.target, step.type.text);
  else if (step.click)   { await clickAnim(page, step.click); await page.click(step.click); }
  else if (step.reaction) await reaction(page, step.reaction);
}

await ctx.close();

// End card 5s
const ctxEnd: BrowserContext = await browser.newContext({
  recordVideo: { dir: '/tmp/poc3-end-out/', size: { width: 1280, height: 720 } },
  viewport: { width: 1280, height: 720 },
});
const pageEnd: Page = await ctxEnd.newPage();
await pageEnd.setContent(`<!DOCTYPE html><html><head><style>*{margin:0;padding:0;box-sizing:border-box}body{width:1280px;height:720px;overflow:hidden;background:radial-gradient(ellipse at center,#87CEEB 0%,#4a90d9 40%,#1a5fa8 100%);display:flex;align-items:center;justify-content:center;font-family:'Arial Black',sans-serif;}.iris{width:580px;height:580px;border-radius:50%;background:radial-gradient(ellipse at center,#87CEEB 0%,#4a90d9 50%,#0a3060 100%);border:12px solid #cc0000;display:flex;flex-direction:column;align-items:center;justify-content:center;box-shadow:0 0 0 8px #ffcc00,0 0 0 16px #cc0000;text-align:center;}.thats{font-size:36px;color:#ffcc00;text-shadow:3px 3px 0 #cc0000;font-style:italic;font-weight:900;letter-spacing:2px;}.all{font-size:72px;color:#ff3300;text-shadow:4px 4px 0 #660000;font-style:italic;font-weight:900;line-height:0.9;}.folks{font-size:28px;color:#fff;text-shadow:2px 2px 0 #333;font-style:italic;margin-top:8px;letter-spacing:1px;}</style></head><body><div class="iris"><div class="thats">É isso aí,</div><div class="all">Por hoje<br>é só</div><div class="folks">pessoal! 🐰</div></div></body></html>`);
await pageEnd.waitForTimeout(5200);
await ctxEnd.close();
await browser.close();

// Pós-produção
const demoWebm = readdirSync(outDir).find(f => f.endsWith('.webm'))!;
const endWebm  = readdirSync('/tmp/poc3-end-out').find(f => f.endsWith('.webm'))!;

execSync(`ffmpeg -y -i ${outDir}/${demoWebm} -c:v libx264 -crf 22 /tmp/poc3-part-demo.mp4`);
execSync(`ffmpeg -y -i /tmp/poc3-end-out/${endWebm} -c:v libx264 -crf 22 /tmp/poc3-part-end.mp4`);

const demoDur = parseFloat(execSync(`ffprobe -v quiet -show_entries format=duration -of csv=p=0 /tmp/poc3-part-demo.mp4`).toString().trim());
const delayMs = Math.round(demoDur * 1000);

writeFileSync('/tmp/poc3-concat.txt', "file '/tmp/poc3-part-demo.mp4'\nfile '/tmp/poc3-part-end.mp4'");
execSync(`ffmpeg -y -f concat -safe 0 -i /tmp/poc3-concat.txt -c copy /tmp/poc3-concat.mp4`);

execSync(`ffmpeg -y \
  -i /tmp/poc3-concat.mp4 \
  -i "${assets}/looney-tunes-theme.mp3" \
  -i "${assets}/looney-tunes-thats-all-folks.mp3" \
  -filter_complex "\
    [1:a]atrim=0:${demoDur},asetpts=PTS-STARTPTS,volume=0.15,afade=t=out:st=${demoDur-1}:d=1[music];\
    [2:a]atrim=0:5,asetpts=PTS-STARTPTS,volume=0.5,adelay=${delayMs}|${delayMs}[outro];\
    [music][outro]amix=inputs=2:duration=longest[audio]" \
  -map 0:v -map "[audio]" \
  -c:v copy -c:a aac -shortest \
  /tmp/poc3-final.mp4`);

console.log('Gerado: /tmp/poc3-final.mp4');
