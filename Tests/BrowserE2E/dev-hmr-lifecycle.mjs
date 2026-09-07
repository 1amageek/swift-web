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
          static CONNECTING = 0;
          static CLOSED = 2;
          static OPEN = 1;
          readyState = 1;
          constructor() { probe.requests++; queueMicrotask(() => this.onopen?.()); }
          addEventListener() {}
          close() { this.readyState = 2; }
        };
      } else {
        delete window.EventSource;
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
  // These peers exercise the served client's native-source failure policy.
  // The reconnect case below separately uses the browser's real EventSource.
  for (const mode of ["terminal", "network-failure", "auth-401", "auth-403", "probe-close"]) {
    const page = await browser.newPage();
    page.on("pageerror", error => report.pageErrors.push(String(error)));
    page.on("console", message => { if (message.type() === "error") report.consoleErrors.push(message.text()); });
    const observations = [];
    await page.exposeFunction("recordProbe", value => observations.push(value));
    await page.addInitScript(({ mode }) => {
      const probe = window.probe = { sources: 0, requests: 0, aborts: 0 };
      window.EventSource = class {
        static CONNECTING = 0;
        static OPEN = 1;
        static CLOSED = 2;
        readyState = 1;
        constructor() { probe.sources++; queueMicrotask(() => this.onopen?.()); }
        addEventListener() {}
        close() { this.readyState = 2; }
      };
      window.fetch = (_url, options) => {
        probe.requests++;
        window.recordProbe({ event: "request", count: probe.requests });
        options.signal.addEventListener("abort", () => {
          probe.aborts++;
          window.recordProbe({ event: "abort", count: probe.aborts });
        });
        if (mode === "network-failure") return Promise.reject(new TypeError("Probe connection failed"));
        if (mode === "probe-close") return new Promise(resolve => {
          options.signal.addEventListener("abort", () => resolve(new Response("late", { status: 401 })));
        });
        const status = mode.startsWith("auth-") ? Number(mode.slice(5)) : 503;
        return Promise.resolve(new Response(new ReadableStream({ start() {} }), { status }));
      };
    }, { mode });
    const pageURL = new URL("/__swiftweb-native-lifecycle-probe", base).href;
    let navigations = 0;
    await page.route(pageURL, route => route.fulfill({ status: 200, contentType: "text/html", body:
      ++navigations === 1
        ? '<!doctype html><script>' + bootstrap[0] + '</script><script src="' + clientURL + '"></script>'
        : '<!doctype html><title>Reloaded</title>' }));
    await page.goto(pageURL, { waitUntil: "domcontentloaded", timeout: 10_000 });
    await page.waitForFunction(() => __swiftWebDevReload.eventSource?.readyState === 1, null, { timeout: 5_000 });
    await page.evaluate(mode => {
      const state = __swiftWebDevReload;
      // CONNECTING is owned by the user agent: no extra source, probe, or timer.
      state.eventSource.readyState = EventSource.CONNECTING;
      state.eventSource.onerror();
      if (probe.requests !== 0 || probe.sources !== 1 || state.reconnectTimer !== null) throw Error("Client took over CONNECTING");
      state.eventSource.readyState = EventSource.OPEN;
      state.eventSource.onopen();
      if (state.lastError !== null) throw Error("OPEN did not clear the transient failure");
      state.eventSource.readyState = EventSource.CLOSED;
      state.eventSource.onerror();
      state.eventSource.onerror();
      if (mode === "probe-close") state.close();
    }, mode);
    if (mode.startsWith("auth-")) {
      await page.waitForFunction(() => document.title === "Reloaded", null, { timeout: 5_000 });
      assert.equal(navigations, 2, "Authentication failure must reload exactly once");
    } else {
      await page.waitForFunction(() => __swiftWebDevReload.closed && __swiftWebDevReload.abortController === null, null, { timeout: 5_000 });
      const result = await page.evaluate(() => ({
        sources: probe.sources, requests: probe.requests, aborts: probe.aborts,
        lastError: __swiftWebDevReload.lastError, status: document.getElementById("devStatus")?.textContent,
        closed: __swiftWebDevReload.closed, timer: __swiftWebDevReload.reconnectTimer,
      }));
      assert.equal(result.sources, 1);
      assert.equal(result.requests, 1);
      assert.equal(result.aborts, 1);
      assert.equal(result.closed, true);
      assert.equal(result.timer, null);
      assert.equal(navigations, 1, "Non-authentication failure must not reload");
      if (mode !== "probe-close") {
        assert.match(result.lastError, mode === "terminal" ? /503/ : /Probe connection failed/);
        assert.match(result.status, /SwiftWeb HMR stopped/);
      }
      report.cases.push({ mode, ...result });
    }
    assert.deepEqual(observations.map(value => value.event), ["request", "abort"], mode);
    if (mode.startsWith("auth-")) report.cases.push({ mode, navigations, observations });
    await page.close();
  }
  {
    const page = await browser.newPage();
    page.on("pageerror", error => report.pageErrors.push(String(error)));
    page.on("console", message => { if (message.type() === "error") report.consoleErrors.push(message.text()); });
    const requests = [];
    await page.addInitScript(() => {
      window.nativeEventSource = EventSource;
      window.probeFetches = 0;
      const fetch = window.fetch.bind(window);
      window.fetch = (...args) => { window.probeFetches++; return fetch(...args); };
    });
    const eventsURL = new URL("/__swiftweb/dev/events", base);
    await page.route(url => url.pathname === eventsURL.pathname, async route => {
      requests.push(await route.request().allHeaders());
      const ordinal = requests.length;
      await route.fulfill({ status: 200, contentType: "text/event-stream", body:
        `retry: ${ordinal === 1 ? 10 : 60000}\nid: native-${ordinal}\nevent: connected\ndata: {"kind":"connected","id":"native-${ordinal}"}\n\n` });
    });
    const pageURL = new URL("/__swiftweb-native-reconnect-probe", base).href;
    await page.route(pageURL, route => route.fulfill({ status: 200, contentType: "text/html", body:
      '<!doctype html><script>' + bootstrap[0] + '</script><script src="' + clientURL + '"></script>' }));
    await page.goto(pageURL, { waitUntil: "domcontentloaded", timeout: 10_000 });
    await page.waitForFunction(() => __swiftWebDevReload.lastEvent?.id === "native-2", null, { timeout: 5_000 });
    const result = await page.evaluate(() => {
      const state = __swiftWebDevReload;
      const selected = state.eventSource instanceof nativeEventSource;
      dispatchEvent(new PageTransitionEvent("pagehide", { persisted: true }));
      const preserved = !state.closed;
      dispatchEvent(new PageTransitionEvent("pagehide", { persisted: false }));
      return { selected, preserved, closed: state.closed, readyState: state.eventSource.readyState,
        fetches: probeFetches, timer: state.reconnectTimer };
    });
    assert.equal(requests.length, 2);
    assert.equal(requests[1]["last-event-id"], "native-1");
    assert.deepEqual(result, { selected: true, preserved: true, closed: true, readyState: 2, fetches: 0, timer: null });
    report.cases.push({ mode: "native-reconnect", ...result, cursor: requests[1]["last-event-id"] });
    await page.close();
  }
  assert.deepEqual(report.pageErrors, []);
  assert.deepEqual(report.consoleErrors, []);
} finally {
  await browser.close();
  report.cleanup = true;
  console.log(JSON.stringify(report, null, 2));
}
