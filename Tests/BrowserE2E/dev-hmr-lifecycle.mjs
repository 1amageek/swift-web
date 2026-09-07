import assert from "node:assert/strict";
import { webkit } from "playwright";

const base = new URL(process.argv[2]);
const response = await fetch(base, { signal: AbortSignal.timeout(10_000) });
assert.equal(response.status, 200);
const html = await response.text();
const bootstrap = html.match(/globalThis\.__swiftWebDevBootstrap\s*=\s*\{[\s\S]*?\};/);
const client = html.match(/<script[^>]+src="([^" ]*\/__swiftweb\/dev\/client\.js[^" ]*)"/);
assert(bootstrap && client, "Expected the running dev server's bootstrap and client script");
const clientURL = new URL(client[1].replaceAll("&amp;", "&"), base).href;
const report = { clientURL, cases: [], pageErrors: [], consoleErrors: [], cleanup: false };
const browser = await webkit.launch({ headless: true });
try {
  for (const mode of ["pagehide", "eof", "replacement", "live-failure", "event-source", "reload-poll"]) {
    const page = await browser.newPage();
    page.on("pageerror", error => report.pageErrors.push(String(error)));
    page.on("console", message => { if (message.type() === "error") report.consoleErrors.push(message.text()); });
    await page.addInitScript(({ mode }) => {
      const probe = window.probe = { requests: 0, aborts: 0, delayed: [] };
      const setTimeout = window.setTimeout.bind(window);
      window.setTimeout = (callback, delay, ...args) => {
        if (delay > 0) probe.delayed.push(callback);
        return setTimeout(callback, delay, ...args);
      };
      if (mode === "event-source") {
        delete window.fetch;
        window.EventSource = class {
          static CLOSED = 2;
          static OPEN = 1;
          readyState = 1;
          constructor() { probe.requests++; queueMicrotask(() => this.onopen?.()); }
          addEventListener() {}
          close() { this.readyState = 2; }
        };
      } else {
        if (mode === "reload-poll") {
          delete window.TextDecoder;
          delete window.EventSource;
        }
        window.fetch = (_url, options) => {
          probe.requests++;
          if (mode === "reload-poll") {
            return new Promise(resolve => options.signal.addEventListener("abort", () => {
              probe.aborts++;
              resolve(new Response(window.__swiftWebDevBootstrap.token));
            }));
          }
          if (mode === "live-failure") return Promise.resolve(new Response("failure", { status: 503 }));
          // Complete the pending reader with EOF, not rejection, when aborted.
          // This exposes a late completion overwriting a terminal readyState.
          return Promise.resolve(new Response(new ReadableStream({ start(controller) {
            let ended = false;
            probe.finishStream = () => { ended = true; controller.close(); };
            options.signal.addEventListener("abort", () => {
              probe.aborts++;
              queueMicrotask(() => { if (!ended) { ended = true; controller.close(); } });
            });
          } }), { status: 200 }));
        };
      }
    }, { mode });
    const pageURL = new URL("/__swiftweb-lifecycle-probe", base).href;
    await page.route(pageURL, route => route.fulfill({ status: 200, contentType: "text/html", body:
      '<!doctype html><title>HMR lifecycle</title><script>' + bootstrap[0] + '</script><script src="' + clientURL + '"></script>' }));
    await page.goto(pageURL, { waitUntil: "domcontentloaded", timeout: 10_000 });
    await page.waitForFunction(() => window.probe.requests === 1, null, { timeout: 5_000 });
    if (mode === "live-failure") {
      await page.waitForFunction(() => window.__swiftWebDevReload.lastError?.includes("503"), null, { timeout: 5_000 });
    } else if (mode !== "reload-poll") {
      await page.waitForFunction(() => window.__swiftWebDevReload.eventSource?.readyState === 1, null, { timeout: 5_000 });
    }
    if (mode === "eof") {
      await page.evaluate(() => probe.finishStream());
      await page.waitForFunction(() => window.__swiftWebDevReload.reconnectTimer !== null, null, { timeout: 5_000 });
      await page.evaluate(() => {
        const resolve = __swiftWebDevReload.reconnectResolve;
        __swiftWebDevReload.reconnectResolve = () => { probe.sleepSettled = true; resolve(); };
      });
    }
    await page.evaluate(mode => {
      window.oldState = window.__swiftWebDevReload;
      if (mode === "pagehide") {
        dispatchEvent(new PageTransitionEvent("pagehide", { persisted: true }));
        if (oldState.closed || oldState.abortController.signal.aborted) throw Error("Persisted pagehide changed the active owner");
        dispatchEvent(new PageTransitionEvent("pagehide", { persisted: false }));
      } else if (mode === "event-source") {
        oldState.eventSource.onerror();
        oldState.close();
        oldState.eventSource.onerror();
      } else if (mode !== "replacement") {
        oldState.close();
      }
    }, mode);
    if (mode === "replacement") await page.addScriptTag({ url: clientURL });
    // Run a callback that was already queued when close cancelled its timer.
    await page.evaluate(() => { for (const callback of probe.delayed.splice(0)) callback(); });
    await page.waitForTimeout(650);
    const result = await page.evaluate(() => ({
      requests: probe.requests, aborts: probe.aborts, closed: oldState.closed,
      readyState: oldState.eventSource?.readyState, reconnectTimer: oldState.reconnectTimer,
      liveError: oldState.lastError, sleepSettled: probe.sleepSettled,
    }));
    report.cases.push({ mode, ...result });
    assert.equal(result.closed, true, mode + " must close its owner");
    assert.equal(result.reconnectTimer, null, mode + " must not retain a reconnect timer");
    assert.equal(result.requests, mode === "replacement" ? 2 : 1, mode + " reconnected after close");
    if (["pagehide", "eof", "replacement"].includes(mode)) {
      assert.equal(result.aborts, 1);
      assert.equal(result.readyState, 2, "Late EOF reopened the stream");
    }
    if (mode === "live-failure") assert.match(result.liveError, /503/);
    if (mode === "eof") assert.equal(result.sleepSettled, true, "Close left the reconnect sleep pending");
    await page.evaluate(() => window.__swiftWebDevReload.close());
    await page.close();
  }
  assert.deepEqual(report.pageErrors, []);
  assert.deepEqual(report.consoleErrors, []);
} finally {
  await browser.close();
  report.cleanup = true;
  console.log(JSON.stringify(report, null, 2));
}
