// Minimal smoke: scene .environment() value must survive SSR snapshot →
// wasm hydration → @Environment read inside a ClientComponent.
// Usage: node env-badge-smoke.mjs <baseURL>
import { chromium } from "playwright";

const baseURL = process.argv[2] || "http://127.0.0.1:3904";
const timeoutMs = 60_000;

const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  page.on("console", (message) => {
    if (message.type() === "error") {
      console.error(`[console.error] ${message.text()}`);
    }
  });
  await page.goto(`${baseURL}/counter`, { waitUntil: "domcontentloaded", timeout: timeoutMs });

  const badge = '[data-accessibility-identifier="environment-badge"]';
  const greeting = `${badge} [data-accessibility-identifier="env-greeting"]`;

  const ssr = (await page.locator(greeting).first().innerText()).trim();
  if (ssr !== "waiting") {
    throw new Error(`SSR should render "waiting" before reveal, got: ${JSON.stringify(ssr)}`);
  }
  console.log("ssr: waiting ✓");

  await page.waitForFunction(
    () => document.documentElement.getAttribute("data-wasm-ready") === "true",
    undefined,
    { timeout: timeoutMs }
  );
  console.log("wasm: ready ✓");

  await page.locator(`${badge} button`).first().click();
  await page.waitForTimeout(2000);
  const afterClick = (await page.locator(greeting).first().innerText()).trim();
  console.log(`after click: ${JSON.stringify(afterClick)}`);
  await page.waitForFunction(
    () => {
      const el = document.querySelector('[data-accessibility-identifier="env-greeting"]');
      return el && el.textContent.trim() === "scene-injected";
    },
    undefined,
    { timeout: timeoutMs }
  );
  console.log("client: scene-injected ✓ (decoded from hydration snapshot in wasm)");
  console.log("ENV-BADGE-SMOKE: PASS");
} finally {
  await browser.close();
}
