import { chromium, type Page, type BrowserContext } from 'playwright';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const demoUrl = `file://${join(__dir, 'demo.html')}`;

// ── Primitivas de overlay ────────────────────────────────────────────────────

async function introModal(page: Page, title: string): Promise<void> {
  await page.evaluate((t: string) => {
    const overlay = document.createElement('div');
    overlay.id = '__nina_intro';
    overlay.style.cssText = `
      position:fixed;inset:0;z-index:99999;
      background:rgba(0,0,0,0.82);
      display:flex;flex-direction:column;
      align-items:center;justify-content:center;
      font-family:Arial,sans-serif;
    `;
    overlay.innerHTML = `
      <div style="color:white;font-size:28px;font-weight:bold;margin-bottom:48px;
        letter-spacing:1px;text-align:center;max-width:600px;line-height:1.4">${t}</div>
      <div id="__nina_cd" style="color:#ff6600;font-size:96px;font-weight:bold;line-height:1">3</div>
    `;
    document.body.appendChild(overlay);
  }, title);
  for (const n of ['2', '1']) {
    await page.waitForTimeout(900);
    await page.evaluate((v: string) => {
      const el = document.getElementById('__nina_cd');
      if (el) el.innerText = v;
    }, n);
  }
  await page.waitForTimeout(900);
  await page.evaluate(() => {
    const el = document.getElementById('__nina_intro') as HTMLElement | null;
    if (!el) return;
    el.style.transition = 'opacity 0.6s ease';
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 650);
  });
  await page.waitForTimeout(700);
}

async function caption(page: Page, text: string): Promise<void> {
  await page.evaluate((t: string) => {
    let el = document.getElementById('__nina_caption') as HTMLElement | null;
    if (!el) {
      el = document.createElement('div');
      el.id = '__nina_caption';
      el.style.cssText = `
        position:fixed;bottom:0;left:0;right:0;
        background:rgba(0,0,0,0.75);color:white;
        font-size:18px;font-family:Arial,sans-serif;
        padding:14px 24px;z-index:99998;
        text-align:center;letter-spacing:0.3px;
      `;
      document.body.appendChild(el);
    }
    el.style.display = 'block';
    el.innerText = t;
  }, text);
}

async function clearCaption(page: Page): Promise<void> {
  await page.evaluate(() => {
    const el = document.getElementById('__nina_caption') as HTMLElement | null;
    if (el) el.style.display = 'none';
  });
}

async function highlight(page: Page, selector: string): Promise<void> {
  await page.evaluate((sel: string) => {
    const el = document.querySelector(sel) as HTMLElement | null;
    if (!el) return;
    el.style.outline = '3px solid #ff6600';
    el.style.boxShadow = '0 0 12px rgba(255,102,0,0.7)';
    setTimeout(() => { el.style.outline = ''; el.style.boxShadow = ''; }, 2000);
  }, selector);
  await page.waitForTimeout(400);
}

async function clickAnim(page: Page, selector: string): Promise<void> {
  const box = await page.locator(selector).boundingBox();
  if (!box) return;
  const cx = box.x + box.width / 2;
  const cy = box.y + box.height / 2;
  await page.evaluate(({ x, y }: { x: number; y: number }) => {
    const dot = document.createElement('div');
    dot.style.cssText = `
      position:fixed;width:32px;height:32px;
      background:rgba(255,102,0,0.85);border-radius:50%;
      left:${x - 16}px;top:${y - 16}px;z-index:99997;
      pointer-events:none;animation:nina-pop 0.45s ease-out forwards;
    `;
    const style = document.createElement('style');
    style.textContent = '@keyframes nina-pop{0%{transform:scale(0.5);opacity:1}100%{transform:scale(2.2);opacity:0}}';
    document.head.appendChild(style);
    document.body.appendChild(dot);
    setTimeout(() => dot.remove(), 500);
  }, { x: cx, y: cy });
  await page.waitForTimeout(300);
}

// ── Demo ─────────────────────────────────────────────────────────────────────

const browser = await chromium.launch({ headless: true });
const context: BrowserContext = await browser.newContext({
  recordVideo: { dir: '/tmp/poc1-out/', size: { width: 1280, height: 720 } },
  viewport: { width: 1280, height: 720 },
});
const page: Page = await context.newPage();

await page.goto(demoUrl);
await page.waitForTimeout(400);
await introModal(page, 'Demonstração da\nFuncionalidade de Pesquisa');
await caption(page, 'Digitando termo de pesquisa...');
await highlight(page, '#filtro');
await page.waitForTimeout(600);
await page.fill('#filtro', 'Bruno');
await page.waitForTimeout(800);
await caption(page, 'Clicando no botão Filtrar...');
await highlight(page, '#btn-filtro');
await clickAnim(page, '#btn-filtro');
await page.click('#btn-filtro');
await page.waitForTimeout(1000);
await caption(page, 'Resultado: apenas clientes com "Bruno" são exibidos.');
await page.waitForTimeout(2000);
await clearCaption(page);
await page.waitForTimeout(500);

await context.close();
await browser.close();
