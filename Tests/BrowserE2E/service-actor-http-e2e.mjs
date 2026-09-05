import assert from "node:assert/strict";
import { chromium } from "playwright";

// Playwright owns signal-driven browser shutdown and process-tree cleanup on exit.
// Bound a stalled graceful shutdown without replacing those handlers.
for (const signal of ["SIGTERM", "SIGINT"]) {
  process.once(signal, () => setTimeout(() => process.exit(1), 5_000).unref());
}

const [base, encodedRequests] = process.argv.slice(2);
const browser = await chromium.launch({
  executablePath: process.env.SWIFTWEB_E2E_BROWSER_EXECUTABLE_PATH,
  headless: true,
  timeout: 15_000,
});
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(base, { waitUntil: "domcontentloaded", timeout: 10_000 });
  const csrf = (await context.cookies(base)).find(cookie => cookie.name === "csrf_token");
  assert.ok(csrf, "The standard security middleware must supply the CSRF cookie");
  const results = [];
  for (const request of JSON.parse(encodedRequests)) {
    results.push(await page.evaluate(async ({ request, token }) => {
      const response = await fetch("/_swiftweb/actors/frame", {
        method: "POST",
        credentials: "same-origin",
        signal: AbortSignal.timeout(10_000),
        headers: {
          "Content-Type": "application/vnd.swift-actor-frame",
          "X-SwiftWeb-Actor-Peer-ID": request.peer,
          "X-CSRF-Token": token,
        },
        body: Uint8Array.from(atob(request.frame), c => c.charCodeAt(0)),
      });
      if (response.status !== 200) throw new Error(`Actor endpoint returned ${response.status}: ${await response.text()}`);
      return btoa(String.fromCharCode(...new Uint8Array(await response.arrayBuffer())));
    }, { request, token: csrf.value }));
  }
  process.stdout.write(JSON.stringify(results));
} finally {
  await browser.close();
}
