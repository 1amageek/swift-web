import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../..");
const require = createRequire(path.join(here, "../package.json"));
const { chromium } = require("playwright");
const buildRequire = process.env.SWIFT_WEB_NODE_MODULES
  ? createRequire(path.join(process.env.SWIFT_WEB_NODE_MODULES, "package.json")) : require;
const { build } = buildRequire("esbuild");
const [wasmPath, javaScriptKitRoot] = process.argv.slice(2);
assert(wasmPath && javaScriptKitRoot, "Expected <wasm> <exact JavaScriptKit checkout>");
const expectedHostCopies = Number(process.env.SWIFTWEB_EXPECT_HOST_COPIES ?? 1);
assert([1, 2].includes(expectedHostCopies), "Expected host copies must be 1 or 2");
const runtime = await build({
  entryPoints: [path.join(javaScriptKitRoot, "Runtime/src/index.ts")],
  bundle: true, format: "esm", platform: "browser", write: false,
});
// Reuse the production WASI implementation verbatim, without its unrelated page host.
const host = await readFile(path.join(root, "Sources/SwiftWebBrowser/Runtime/SwiftWebWasmRuntimeHostScript.swift"), "utf8");
const begin = host.indexOf("    class SwiftWebWASI {");
const end = host.indexOf("    function findEventTarget(", begin);
assert(begin >= 0 && end > begin, "Production WASI source boundary changed");
const wasi = host.slice(begin, end);
const bridgeBegin = host.indexOf("    function swiftWebBridgeJSStubs() {");
const bridgeEnd = host.indexOf("    class SwiftWebWasmRuntime {", bridgeBegin);
assert(bridgeBegin >= 0 && bridgeEnd > bridgeBegin, "Production BridgeJS source boundary changed");
const bridge = host.slice(bridgeBegin, bridgeEnd);
const wasm = await readFile(wasmPath);
const report = { rows: [], pageErrors: [], consoleErrors: [], requestFailures: [], cleanup: false };
const script = `${wasi}\n${bridge}\n(${browserProbe.toString()})();`;
const assets = new Map([
  ["/", ["text/html", '<link rel="icon" href="data:,"><script type="module" src="/probe.js"></script>']],
  ["/probe.js", ["text/javascript", script]],
  ["/runtime.js", ["text/javascript", runtime.outputFiles[0].contents]],
  ["/probe.wasm", ["application/wasm", wasm]],
]);
const server = createServer((request, response) => {
  const asset = assets.get(request.url);
  response.writeHead(asset ? 200 : 404, { "Content-Type": asset?.[0] ?? "text/plain" });
  response.end(asset?.[1] ?? "Not found");
});
let browser;
let page;
try {
  browser = await chromium.launch({ channel: "chrome", headless: true });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  page = await browser.newPage();
  page.on("pageerror", (error) => report.pageErrors.push(String(error)));
  page.on("console", (message) => { if (message.type() === "error") report.consoleErrors.push(message.text()); });
  page.on("requestfailed", (request) => report.requestFailures.push({ url: request.url(), error: request.failure() }));
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  await page.waitForFunction(() => globalThis.probeDone || globalThis.probeFailure, null, { timeout: 30_000 });
  const result = await page.evaluate(() => ({ failure: globalThis.probeFailure, rows: globalThis.probeRows, aborted: globalThis.probeAborted }));
  Object.assign(report, result);
  assert.equal(result.failure, undefined);
  assert.equal(result.rows.length, 4);
  assert.equal(result.aborted, 4);
  for (const row of result.rows) {
    assert.equal(row.verified, true);
    assert.equal(row.outboundCalls, row.branch === "host" ? expectedHostCopies : 1);
    assert.equal(row.outboundBytes, row.outboundCalls * row.requestBytes);
    assert.equal(row.inboundCalls, 1);
    assert.equal(row.inboundBytes, row.responseBytes);
  }
  assert.deepEqual(report.pageErrors, []);
  assert.deepEqual(report.consoleErrors, []);
  assert.deepEqual(report.requestFailures, []);
} catch (error) {
  if (page) report.failureSnapshot = await page.evaluate(() => ({
    stage: globalThis.probeStage, rows: globalThis.probeRows,
    failure: globalThis.probeFailure, entered: globalThis.probeEntered,
  }));
  throw error;
} finally {
  if (browser) await browser.close();
  if (server.listening) await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  report.cleanup = true;
  console.log(JSON.stringify(report, null, 2));
}

async function browserProbe() {
  try {
    globalThis.probeStage = "runtime.import";
    const { SwiftRuntime } = await import("/runtime.js");
    const runtime = new SwiftRuntime();
    const wasi = new SwiftWebWASI();
    const originalFetch = globalThis.fetch.bind(globalThis);
    let mode = "success", expected, responseBytes, row, measuring = false;
    globalThis.probeRows = [];
    globalThis.probeAborted = 0;
    function request(body, signal) {
      if (!(body instanceof Uint8Array) || body.length !== expected.length || !body.every((byte, index) => byte === expected[index])) {
        throw new Error("Outbound bytes differ from actual Swift codec output");
      }
      if (mode === "pending") {
        globalThis.probeEntered = true;
        return new Promise((resolve, reject) => signal.addEventListener("abort", () => {
          globalThis.probeAborted += 1;
          reject(new DOMException("Aborted", "AbortError"));
        }, { once: true }));
      }
      return Promise.resolve(new Response(mode === "empty" ? new Uint8Array() : responseBytes, {
        status: mode === "unavailable" ? 503 : 200,
      }));
    }
    globalThis.probePrepare = (branch, payloadBytes, requestBytes, resultBytes) => {
      globalThis.probeStage = `${branch}/${payloadBytes}/prepared`;
      expected = requestBytes;
      responseBytes = resultBytes;
      mode = "success";
      row = { branch, payloadBytes, requestBytes: requestBytes.length, responseBytes: resultBytes.length,
        outboundCalls: 0, outboundBytes: 0, inboundCalls: 0, inboundBytes: 0, verified: false };
      globalThis.probeRows.push(row);
      globalThis.fetch = (url, options) => url === "/actor" ? request(options.body, options.signal) : originalFetch(url, options);
      globalThis.__swiftWebActorRequest = branch === "host" ? (url, body, signal) => request(body, signal) : undefined;
    };
    globalThis.probeBegin = () => { measuring = true; globalThis.probeStage = "send"; };
    globalThis.probeEnd = () => { measuring = false; globalThis.probeStage = "sent"; };
    globalThis.probeMode = (value) => { mode = value; globalThis.probeEntered = false; globalThis.probeStage = value; };
    globalThis.probeVerified = () => { row.verified = true; };
    const imports = runtime.wasmImports;
    for (const [name, direction] of [["swjs_create_typed_array", "outbound"], ["swjs_copy_typed_array_bytes", "inbound"]]) {
      const original = imports[name];
      if (typeof original !== "function") throw new Error(`Missing pinned ABI import ${name}`);
      imports[name] = (...args) => {
        const result = original(...args);
        if (measuring) {
          row[`${direction}Calls`] += 1;
          // Only UInt8 arrays cross this measured path; lengths equal byte counts.
          row[`${direction}Bytes`] += args[2];
        }
        return result;
      };
    }
    const { instance } = await WebAssembly.instantiateStreaming(originalFetch("/probe.wasm"), {
      bjs: swiftWebBridgeJSStubs(), javascript_kit: imports, wasi_snapshot_preview1: wasi.imports,
    });
    wasi.bind(instance);
    runtime.setInstance(instance);
    if (typeof instance.exports.main !== "function" && typeof instance.exports.__main_argc_argv !== "function") {
      throw new Error("The reactor must export its actual Swift entry point");
    }
    if (typeof instance.exports.swjs_call_host_function !== "function") {
      throw new Error("JavaScriptKit must export its host callback entry point");
    }
    globalThis.probeStage = "runtime.initialize";
    instance.exports._initialize();
    globalThis.probeStage = "runtime.main";
    runtime.main();
  } catch (error) {
    globalThis.probeFailure = error.stack ?? String(error);
  }
}
