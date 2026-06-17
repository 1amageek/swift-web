import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);

if (process.env.SWIFTWEB_BROWSER_E2E !== "1") {
  console.log("Skipping SwiftWeb browser E2E. Set SWIFTWEB_BROWSER_E2E=1 to run.");
  process.exit(0);
}

let chromium;
try {
  ({ chromium } = require("playwright"));
} catch (error) {
  console.error("Playwright is required. Run `npm install` in Tests/BrowserE2E first.");
  console.error(String(error && error.message ? error.message : error));
  process.exit(2);
}

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const swiftWebRoot = path.resolve(scriptDirectory, "../..");
const defaultSwiftHTMLRoot = path.resolve(swiftWebRoot, "../swift-html");
const swiftHTMLRoot = path.resolve(process.env.SWIFTWEB_E2E_SWIFT_HTML_ROOT || defaultSwiftHTMLRoot);
const exampleAppRoot = path.join(swiftWebRoot, "Examples", "CounterApp");
const timeoutMs = Number(process.env.SWIFTWEB_E2E_TIMEOUT_MS || 600_000);
const hmrTimeoutMs = Number(process.env.SWIFTWEB_E2E_HMR_TIMEOUT_MS || 90_000);
const report = {
  phases: [],
  consoleErrors: [],
  browserErrors: [],
  serverLogTail: [],
};

function recordPhase(name, detail = {}) {
  const entry = {
    name,
    at: new Date().toISOString(),
    ...detail,
  };
  report.phases.push(entry);
  console.log(`[counter-wasm-e2e] ${name}`);
}

function swiftStringLiteral(value) {
  return value
    .replaceAll("\\", "\\\\")
    .replaceAll("\"", "\\\"")
    .replaceAll("\n", "\\n")
    .replaceAll("\r", "\\r");
}

async function availablePort() {
  if (process.env.SWIFTWEB_E2E_PORT) {
    return Number(process.env.SWIFTWEB_E2E_PORT);
  }
  return await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

async function waitForHTTP(url, deadline) {
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "text/html",
        },
      });
      if (response.ok) {
        return;
      }
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await delay(1_000);
  }
  throw new Error(`Timed out waiting for ${url}: ${String(lastError && lastError.message ? lastError.message : lastError)}`);
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function prepareAppCopy(root) {
  const appRoot = path.join(root, "CounterApp");
  await cp(exampleAppRoot, appRoot, {
    recursive: true,
    filter(source) {
      const name = path.basename(source);
      return name !== ".build" && name !== ".swiftweb" && name !== "Package.resolved";
    },
  });

  const packageFile = path.join(appRoot, "Package.swift");
  let manifest = await readFile(packageFile, "utf8");
  manifest = manifest.replace(
    /\.package\(path:\s*"[^"]*"\),\s*\n\s*\.package\((?:path|url):\s*"[^"]+"(?:,[^\n]*)?\),/,
    `.package(path: "${swiftStringLiteral(swiftWebRoot)}"),\n        .package(path: "${swiftStringLiteral(swiftHTMLRoot)}"),`
  );
  if (!manifest.includes(swiftStringLiteral(swiftWebRoot)) || !manifest.includes(swiftStringLiteral(swiftHTMLRoot))) {
    throw new Error("Failed to rewrite CounterApp package dependencies to local swift-web and swift-html paths.");
  }
  await writeFile(packageFile, manifest);
  return appRoot;
}

async function launchDevServer(appRoot, scratchRoot, port) {
  const child = spawn(
    "swift",
    [
      "run",
      "--package-path",
      swiftWebRoot,
      "swift-web",
      "dev",
      "--package-path",
      appRoot,
      "--scratch-path",
      scratchRoot,
      "--port",
      String(port),
    ],
    {
      cwd: swiftWebRoot,
      env: {
        ...process.env,
        SWIFT_WEB_WASM_SDK: process.env.SWIFT_WEB_WASM_SDK || "swift-6.3.1-RELEASE_wasm",
      },
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    }
  );

  const appendLog = (chunk) => {
    const lines = String(chunk).split(/\r?\n/).filter(Boolean);
    report.serverLogTail.push(...lines);
    if (report.serverLogTail.length > 160) {
      report.serverLogTail.splice(0, report.serverLogTail.length - 160);
    }
    for (const line of lines) {
      console.log(`[swift-web dev] ${line}`);
    }
  };
  child.stdout.on("data", appendLog);
  child.stderr.on("data", appendLog);

  child.once("exit", (code, signal) => {
    report.serverExit = { code, signal };
  });

  return child;
}

async function stopProcess(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) {
    return;
  }
  try {
    process.kill(-child.pid, "SIGTERM");
  } catch {
    child.kill("SIGTERM");
  }
  const exited = await Promise.race([
    new Promise((resolve) => child.once("exit", resolve)),
    delay(8_000).then(() => false),
  ]);
  if (exited === false && child.exitCode === null && child.signalCode === null) {
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch {
      child.kill("SIGKILL");
    }
    await new Promise((resolve) => child.once("exit", resolve));
  }
}

async function removeTemporaryRoot(root) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      await rm(root, { recursive: true, force: true });
      return;
    } catch (error) {
      if (attempt === 4) {
        throw error;
      }
      await delay(1_000 * (attempt + 1));
    }
  }
}

function systemChromeExecutablePath() {
  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
  ];
  return candidates.find((candidate) => existsSync(candidate)) || null;
}

async function launchBrowser() {
  const headless = process.env.SWIFTWEB_E2E_HEADFUL !== "1";
  const configuredExecutable = process.env.SWIFTWEB_E2E_BROWSER_EXECUTABLE_PATH;
  const launchOptions = { headless };
  if (configuredExecutable) {
    launchOptions.executablePath = configuredExecutable;
  } else {
    const systemBrowser = systemChromeExecutablePath();
    if (systemBrowser) {
      launchOptions.executablePath = systemBrowser;
    }
  }

  try {
    return await chromium.launch(launchOptions);
  } catch (error) {
    if (!configuredExecutable && !launchOptions.executablePath) {
      return await chromium.launch({ headless, channel: "chrome" });
    }
    throw error;
  }
}

async function cardValue(page, selector) {
  const text = await page.locator(`${selector} .swui-value`).first().innerText();
  return Number(text.trim());
}

async function expectCardValue(page, selector, expected) {
  await page.waitForFunction(
    ({ selector, expected }) => {
      const value = document.querySelector(`${selector} .swui-value`);
      return value && value.textContent.trim() === String(expected);
    },
    { selector, expected },
    { timeout: timeoutMs }
  );
}

async function browserRuntimeState(page) {
  return await page.evaluate(() => ({
    devReload: {
      exists: !!globalThis.__swiftWebDevReload,
      eventSourceReadyState: globalThis.__swiftWebDevReload?.eventSource?.readyState ?? null,
      connectedAt: globalThis.__swiftWebDevReload?.connectedAt ?? null,
      lastEventKind: globalThis.__swiftWebDevReload?.lastEvent?.kind ?? null,
      lastAppliedEventKind: globalThis.__swiftWebDevReload?.lastAppliedEvent?.kind ?? null,
      lastError: globalThis.__swiftWebDevReload?.lastError ?? null,
    },
    wasmStatus: globalThis.__swiftWebWasmRuntimeStatus ?? null,
    wasmMetrics: globalThis.__swiftWebWasmRuntimeMetrics ?? null,
    documentHasDevScript: document.documentElement.outerHTML.includes("__swiftWebDevReload"),
  }));
}

async function runBrowserAssertions(baseURL, appRoot) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    page.on("console", (message) => {
      if (message.type() === "error") {
        report.consoleErrors.push(message.text());
      }
    });
    page.on("pageerror", (error) => {
      report.browserErrors.push(String(error && error.message ? error.message : error));
    });

    recordPhase("browser.goto");
    await page.goto(`${baseURL}/counter`, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await page.waitForFunction(
      () => document.documentElement.getAttribute("data-swift-web-wasm-ready") === "true",
      undefined,
      { timeout: timeoutMs }
    );
    await page.evaluate(() => {
      window.__swiftWebE2EMarker = crypto.randomUUID();
    });
    const initialMarker = await page.evaluate(() => window.__swiftWebE2EMarker);
    const runtime = await page.evaluate(() => ({
      status: window.__swiftWebWasmRuntimeStatus,
      metrics: window.__swiftWebWasmRuntimeMetrics,
      loadedAttribute: document.documentElement.getAttribute("data-swift-web-wasm-loaded"),
    }));
    if (!runtime.status || runtime.status.ready !== true) {
      throw new Error(`WASM runtime did not report ready: ${JSON.stringify(runtime.status)}`);
    }
    if (!runtime.metrics || !Array.isArray(runtime.metrics.bundles) || runtime.metrics.bundles.length === 0) {
      throw new Error("WASM runtime metrics did not record any loaded bundle.");
    }
    if (!String(runtime.loadedAttribute || "").includes("counter-wasm-runtime")) {
      throw new Error(`counter-wasm-runtime was not loaded: ${runtime.loadedAttribute || ""}`);
    }
    report.initialRuntime = runtime;
    recordPhase("wasm.ready", {
      loaded: runtime.loadedAttribute,
      bytes: runtime.metrics.summary && runtime.metrics.summary.totalWasmBytes,
    });
    try {
      await page.waitForFunction(
        () => !!globalThis.__swiftWebDevReload?.connectedAt && !!globalThis.__swiftWebDevReload?.eventSource,
        undefined,
        { timeout: hmrTimeoutMs }
      );
    } catch (error) {
      report.devReloadOpenFailure = await browserRuntimeState(page);
      throw error;
    }
    report.devReloadAfterPageLoad = await browserRuntimeState(page);

    await expectCardValue(page, ".client-counter", 0);
    await expectCardValue(page, ".server-counter", 0);

    recordPhase("client.increment");
    await page.locator(".client-counter").getByRole("button", { name: "Increment" }).click();
    await expectCardValue(page, ".client-counter", 1);
    const markerAfterClient = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterClient !== initialMarker) {
      throw new Error("Client WASM event caused a full page reload.");
    }
    const clientDispatchCount = await page.evaluate(() => window.__swiftWebWasmRuntimeMetrics.summary.eventDispatchCount || 0);
    if (clientDispatchCount < 1) {
      throw new Error("Client WASM event dispatch metrics were not recorded.");
    }

    recordPhase("server.increment.invalidate");
    await page.locator(".server-counter").getByRole("button", { name: "Increment" }).click();
    await expectCardValue(page, ".server-counter", 1);
    await expectCardValue(page, ".client-counter", 1);
    const markerAfterServer = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterServer !== initialMarker) {
      throw new Error("ServerAction invalidate caused a full page reload.");
    }

    report.devReloadBeforeHMR = await browserRuntimeState(page);

    recordPhase("client.hmr.source-change");
    const clientCounterFile = path.join(appRoot, "Sources", "CounterApp", "ClientCounter.swift");
    const originalSource = await readFile(clientCounterFile, "utf8");
    const updatedSource = originalSource.replace("Heading(\"Client Counter\")", "Heading(\"Client Counter HMR\")");
    if (updatedSource === originalSource) {
      throw new Error("HMR source marker was not found in ClientCounter.swift.");
    }
    await writeFile(clientCounterFile, updatedSource);

    try {
      await page.waitForFunction(
        () => document.body && document.body.textContent.includes("Client Counter HMR"),
        undefined,
        { timeout: hmrTimeoutMs }
      );
    } catch (error) {
      report.devReloadAfterHMRFailure = await browserRuntimeState(page);
      throw error;
    }
    await expectCardValue(page, ".client-counter", 1);
    const markerAfterHMR = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterHMR !== initialMarker) {
      throw new Error("ClientComponent HMR caused a full page reload.");
    }
    const hmrMetrics = await page.evaluate(() => {
      const metrics = window.__swiftWebWasmRuntimeMetrics || {};
      return {
        events: (metrics.events || []).filter((event) => String(event.name || "").startsWith("hmr.")),
        loadedBundleIDs: metrics.loadedBundleIDs || [],
        summary: metrics.summary || {},
      };
    });
    if (!hmrMetrics.events.some((event) => event.name === "hmr.clientComponent.complete")) {
      throw new Error(`ClientComponent HMR completion was not recorded: ${JSON.stringify(hmrMetrics.events)}`);
    }
    report.hmrMetrics = hmrMetrics;
    recordPhase("client.hmr.state-preserved");

    const finalValues = {
      client: await cardValue(page, ".client-counter"),
      server: await cardValue(page, ".server-counter"),
    };
    report.finalValues = finalValues;
    if (finalValues.client !== 1 || finalValues.server !== 1) {
      throw new Error(`Unexpected final values: ${JSON.stringify(finalValues)}`);
    }
  } finally {
    await browser.close();
  }
}

let tempRoot;
let devServer;

try {
  if (!existsSync(swiftHTMLRoot)) {
    throw new Error(`Local swift-html package was not found: ${swiftHTMLRoot}`);
  }
  tempRoot = await mkdtemp(path.join(tmpdir(), "swiftweb-counter-e2e-"));
  const appRoot = await prepareAppCopy(tempRoot);
  const scratchRoot = path.join(tempRoot, "scratch");
  await mkdir(scratchRoot, { recursive: true });
  const port = await availablePort();
  const baseURL = `http://127.0.0.1:${port}`;
  report.tempRoot = tempRoot;
  report.appRoot = appRoot;
  report.baseURL = baseURL;

  recordPhase("server.start", { baseURL });
  devServer = await launchDevServer(appRoot, scratchRoot, port);
  await waitForHTTP(`${baseURL}/counter`, Date.now() + timeoutMs);
  recordPhase("server.ready");

  await runBrowserAssertions(baseURL, appRoot);
  recordPhase("passed");
} catch (error) {
  report.error = String(error && error.stack ? error.stack : error);
  console.error(report.error);
  process.exitCode = 1;
} finally {
  await stopProcess(devServer);
  if (tempRoot && process.env.SWIFTWEB_E2E_KEEP_TEMP !== "1") {
    await removeTemporaryRoot(tempRoot);
  }
  const output = JSON.stringify(report, null, 2);
  console.log(output);
}
