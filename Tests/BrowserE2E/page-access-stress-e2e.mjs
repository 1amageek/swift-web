import { createRequire } from "node:module";
import { execFile, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { performance } from "node:perf_hooks";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const require = createRequire(import.meta.url);
const execFileAsync = promisify(execFile);

if (process.env.SWIFTWEB_BROWSER_E2E !== "1") {
  console.log("Skipping SwiftWeb page access stress E2E. Set SWIFTWEB_BROWSER_E2E=1 to run.");
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
const exampleAppRoot = path.join(swiftWebRoot, "Examples", "HelloWorld");
const testPath = "/";
const expectedPageText = "Hello, World!";
const profileName = process.env.SWIFTWEB_PAGE_ACCESS_PROFILE || "stress";
const profile = profileName === "performance"
  ? {
    httpIterations: 60,
    httpConcurrency: 4,
    browserIterations: 12,
    requestTimeoutMs: 5_000,
    browserReadyTimeoutMs: 10_000,
    maxHTTPP95Ms: 2_500,
    reuseBrowserPage: true,
  }
  : {
    httpIterations: 240,
    httpConcurrency: 8,
    browserIterations: 40,
    requestTimeoutMs: 8_000,
    browserReadyTimeoutMs: 15_000,
    maxHTTPP95Ms: null,
    reuseBrowserPage: false,
  };
const startupTimeoutMs = Number(process.env.SWIFTWEB_E2E_TIMEOUT_MS || 600_000);
const requestTimeoutMs = Number(process.env.SWIFTWEB_PAGE_ACCESS_REQUEST_TIMEOUT_MS || profile.requestTimeoutMs);
const browserReadyTimeoutMs = Number(process.env.SWIFTWEB_PAGE_ACCESS_BROWSER_TIMEOUT_MS || profile.browserReadyTimeoutMs);
const httpIterations = Number(process.env.SWIFTWEB_PAGE_ACCESS_HTTP_ITERATIONS || profile.httpIterations);
const httpConcurrency = Number(process.env.SWIFTWEB_PAGE_ACCESS_HTTP_CONCURRENCY || profile.httpConcurrency);
const browserIterations = Number(process.env.SWIFTWEB_PAGE_ACCESS_BROWSER_ITERATIONS || profile.browserIterations);
const maxHTTPP95Ms = process.env.SWIFTWEB_PAGE_ACCESS_MAX_HTTP_P95_MS
  ? Number(process.env.SWIFTWEB_PAGE_ACCESS_MAX_HTTP_P95_MS)
  : profile.maxHTTPP95Ms;
const reuseBrowserPage = process.env.SWIFTWEB_PAGE_ACCESS_REUSE_BROWSER_PAGE
  ? process.env.SWIFTWEB_PAGE_ACCESS_REUSE_BROWSER_PAGE === "1"
  : profile.reuseBrowserPage;

const report = {
  profile: profileName,
  phases: [],
  consoleErrors: [],
  browserErrors: [],
  httpFailures: [],
  serverLogTail: [],
  httpOutliers: [],
  browserSamples: [],
};

function recordPhase(name, detail = {}) {
  const entry = {
    name,
    at: new Date().toISOString(),
    ...detail,
  };
  report.phases.push(entry);
  console.log(`[page-access-${profileName}] ${name}`);
}

function swiftStringLiteral(value) {
  return value
    .replaceAll("\\", "\\\\")
    .replaceAll("\"", "\\\"")
    .replaceAll("\n", "\\n")
    .replaceAll("\r", "\\r");
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

async function waitForHTTP(url, deadline, child = null) {
  let lastError = null;
  while (Date.now() < deadline) {
    if (child) {
      assertServerRunning(child, `waiting for ${url}`);
    }
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

async function prepareAppCopy(root) {
  const appRoot = path.join(root, "HelloWorld");
  await cp(exampleAppRoot, appRoot, {
    recursive: true,
    filter(source) {
      const name = path.basename(source);
      return name !== ".build" && name !== ".swiftweb";
    },
  });

  const packageFile = path.join(appRoot, "Package.swift");
  let manifest = await readFile(packageFile, "utf8");
  manifest = manifest.replace(
    /\.package\((?:path:\s*"[^"]+"|url:\s*"https:\/\/github\.com\/1amageek\/swift-web\.git"[^)]*)\)/,
    `.package(path: "${swiftStringLiteral(swiftWebRoot)}")`
  );
  manifest = manifest.replace(
    /\.package\(url:\s*"https:\/\/github\.com\/1amageek\/swift-html\.git"[^)]*\)/,
    `.package(path: "${swiftStringLiteral(swiftHTMLRoot)}")`
  );
  if (!manifest.includes(swiftStringLiteral(swiftWebRoot)) || !manifest.includes(swiftStringLiteral(swiftHTMLRoot))) {
    throw new Error("Failed to rewrite HelloWorld package dependencies to local swift-web and swift-html paths.");
  }
  await writeFile(packageFile, manifest);
  return appRoot;
}

async function launchDevServer(appRoot, scratchRoot, port) {
  const swiftWebExecutable = await resolveSwiftWebExecutable();
  const wasmSwiftSDK = process.env.SWIFT_WEB_WASM_SDK || "swift-6.3.1-RELEASE_wasm";
  report.swiftWebExecutable = swiftWebExecutable;
  report.wasmSwiftSDK = wasmSwiftSDK;
  if (process.env.SWIFT_WEB_WASM_SWIFT) {
    report.wasmSwiftExecutable = process.env.SWIFT_WEB_WASM_SWIFT;
  }
  if (process.env.SWIFT_WEB_WASM_TOOLCHAIN_BIN) {
    report.wasmSwiftToolchainBin = process.env.SWIFT_WEB_WASM_TOOLCHAIN_BIN;
  }

  const child = spawn(
    swiftWebExecutable,
    [
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
        SWIFT_WEB_PACKAGE_PATH: swiftWebRoot,
        SWIFT_WEB_WASM_SDK: wasmSwiftSDK,
      },
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    }
  );

  const appendLog = (chunk) => {
    const lines = String(chunk).split(/\r?\n/).filter(Boolean);
    report.serverLogTail.push(...lines);
    if (report.serverLogTail.length > 240) {
      report.serverLogTail.splice(0, report.serverLogTail.length - 240);
    }
    for (const line of lines) {
      console.log(`[sweb dev] ${line}`);
    }
  };
  child.stdout.on("data", appendLog);
  child.stderr.on("data", appendLog);
  child.once("exit", (code, signal) => {
    report.serverExit = { code, signal };
  });
  return child;
}

async function resolveSwiftWebExecutable() {
  const configuredExecutable = process.env.SWIFTWEB_CLI_EXECUTABLE;
  if (configuredExecutable) {
    if (!existsSync(configuredExecutable)) {
      throw new Error(`SWIFTWEB_CLI_EXECUTABLE does not exist: ${configuredExecutable}`);
    }
    return configuredExecutable;
  }

  recordPhase("cli.build");
  const swiftCommand = await resolveHostSwiftCommand();
  await execFileAsync(
    swiftCommand.executable,
    [
      ...swiftCommand.arguments,
      "build",
      "--disable-sandbox",
      "--package-path",
      swiftWebRoot,
      "--product",
      "sweb",
    ],
    {
      cwd: swiftWebRoot,
      env: process.env,
      maxBuffer: 100 * 1024 * 1024,
    }
  );

  const { stdout } = await execFileAsync(
    swiftCommand.executable,
    [
      ...swiftCommand.arguments,
      "build",
      "--disable-sandbox",
      "--package-path",
      swiftWebRoot,
      "--show-bin-path",
    ],
    {
      cwd: swiftWebRoot,
      env: process.env,
      maxBuffer: 10 * 1024 * 1024,
    }
  );
  const binPath = stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .at(-1);
  if (!binPath) {
    throw new Error("Unable to resolve sweb binary path.");
  }

  const executable = path.join(binPath, "sweb");
  if (!existsSync(executable)) {
    throw new Error(`Resolved sweb executable does not exist: ${executable}`);
  }
  return executable;
}

async function resolveHostSwiftCommand() {
  const configuredExecutable = process.env.SWIFTWEB_E2E_HOST_SWIFT_EXECUTABLE
    || process.env.SWIFTWEB_E2E_SWIFT_EXECUTABLE
    || process.env.SWIFT_WEB_SWIFT;
  const candidates = [
    configuredExecutable ? {
      executable: configuredExecutable,
      arguments: [],
      label: configuredExecutable,
    } : null,
    {
      executable: "xcrun",
      arguments: ["swift"],
      label: "xcrun swift",
    },
    {
      executable: "swift",
      arguments: [],
      label: "swift",
    },
    {
      executable: "/Users/1amageek/.swiftly/bin/swift",
      arguments: [],
      label: "/Users/1amageek/.swiftly/bin/swift",
    },
  ].filter(Boolean);

  const failures = [];
  for (const candidate of candidates) {
    try {
      if (path.isAbsolute(candidate.executable) && !existsSync(candidate.executable)) {
        failures.push(`${candidate.label}: not found`);
        continue;
      }
      const { stdout, stderr } = await execFileAsync(candidate.executable, [...candidate.arguments, "--version"], {
        cwd: swiftWebRoot,
        env: process.env,
        maxBuffer: 10 * 1024 * 1024,
      });
      const version = `${stdout}${stderr}`.trim();
      const parsedVersion = parseSwiftVersion(version);
      if (!parsedVersion || !isAtLeastSwift64(parsedVersion)) {
        failures.push(`${candidate.label}: ${version.split(/\r?\n/)[0] || "unknown version"}`);
        continue;
      }
      report.hostSwiftExecutable = candidate.label;
      report.hostSwiftVersion = version;
      return candidate;
    } catch (error) {
      failures.push(`${candidate.label}: ${String(error && error.message ? error.message : error)}`);
    }
  }

  throw new Error(`Swift 6.4-capable host executable was not found. Checked: ${failures.join("; ")}`);
}

function parseSwiftVersion(version) {
  const match = version.match(/Swift version\s+(\d+)\.(\d+)(?:\.(\d+))?/);
  if (!match) {
    return null;
  }
  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3] || 0),
  };
}

function isAtLeastSwift64(version) {
  if (version.major > 6) {
    return true;
  }
  if (version.major < 6) {
    return false;
  }
  return version.minor >= 4;
}

async function stopProcess(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) {
    return;
  }
  try {
    child.kill("SIGTERM");
  } catch {
    // The process may have already exited between the status check and signal.
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

function assertServerRunning(child, context) {
  if (!child || child.exitCode === null && child.signalCode === null) {
    return;
  }
  throw new Error(`${context}: SwiftWeb dev server exited early: ${JSON.stringify(report.serverExit || {})}`);
}

async function fetchTextWithTimeout(url, timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const startedAt = performance.now();
  try {
    const response = await fetch(url, {
      headers: {
        Accept: "text/html",
      },
      signal: controller.signal,
    });
    const text = await response.text();
    return {
      status: response.status,
      ok: response.ok,
      text,
      elapsedMs: performance.now() - startedAt,
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function runHTTPAccessLoop(baseURL, child) {
  recordPhase("http.loop.start", {
    iterations: httpIterations,
    concurrency: httpConcurrency,
    requestTimeoutMs,
  });

  let nextIteration = 0;
  const latencies = [];
  const worker = async (workerIndex) => {
    while (true) {
      const iteration = nextIteration;
      nextIteration += 1;
      if (iteration >= httpIterations) {
        return;
      }

      assertServerRunning(child, `HTTP iteration ${iteration}`);
      const url = `${baseURL}${testPath}?stress=http-${iteration}`;
      let result;
      try {
        result = await fetchTextWithTimeout(url, requestTimeoutMs);
      } catch (error) {
        throw new Error(`HTTP iteration ${iteration} timed out or failed on worker ${workerIndex}: ${String(error && error.message ? error.message : error)}`);
      }
      if (!result.ok) {
        throw new Error(`HTTP iteration ${iteration} returned ${result.status}`);
      }
      if (!result.text.includes(expectedPageText)) {
        throw new Error(`HTTP iteration ${iteration} returned unexpected page content.`);
      }
      latencies.push(result.elapsedMs);
      if (result.elapsedMs > requestTimeoutMs * 0.5) {
        report.httpOutliers.push({
          iteration,
          workerIndex,
          elapsedMs: Math.round(result.elapsedMs),
        });
      }
    }
  };

  await Promise.all(Array.from({ length: httpConcurrency }, (_, index) => worker(index)));
  report.httpLatency = summarizeLatencies(latencies);
  if (maxHTTPP95Ms !== null && report.httpLatency.p95Ms > maxHTTPP95Ms) {
    throw new Error(`HTTP p95 latency ${report.httpLatency.p95Ms}ms exceeded ${maxHTTPP95Ms}ms.`);
  }
  recordPhase("http.loop.passed", report.httpLatency);
}

function summarizeLatencies(values) {
  const sorted = values.slice().sort((a, b) => a - b);
  const percentile = (p) => {
    if (sorted.length === 0) {
      return 0;
    }
    const index = p <= 0
      ? 0
      : Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
    return Math.round(sorted[index]);
  };
  const total = sorted.reduce((sum, value) => sum + value, 0);
  return {
    count: sorted.length,
    minMs: percentile(0),
    p50Ms: percentile(50),
    p95Ms: percentile(95),
    maxMs: percentile(100),
    averageMs: sorted.length === 0 ? 0 : Math.round(total / sorted.length),
  };
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

function attachPageDiagnostics(page, browserName) {
  page.on("response", (response) => {
    const url = new URL(response.url());
    if (response.status() >= 400) {
      report.httpFailures.push({
        browser: browserName,
        url: response.url(),
        path: url.pathname,
        status: response.status(),
        at: new Date().toISOString(),
      });
    }
  });
  page.on("console", (message) => {
    if (message.type() === "error" && !isAllowedConsoleError(message.text())) {
      report.consoleErrors.push({
        browser: browserName,
        text: message.text(),
        at: new Date().toISOString(),
      });
    }
  });
  page.on("pageerror", (error) => {
    report.browserErrors.push({
      browser: browserName,
      message: String(error && error.message ? error.message : error),
      at: new Date().toISOString(),
    });
  });
}

function isAllowedConsoleError(text) {
  return text === "Failed to load resource: the server responded with a status of 404 (Not Found)";
}

function isAllowedHTTPFailure(failure) {
  return failure.path === "/favicon.ico" && failure.status === 404;
}

function assertNoUnexpectedBrowserDiagnostics() {
  const unexpectedHTTPFailures = report.httpFailures.filter((failure) => !isAllowedHTTPFailure(failure));
  if (unexpectedHTTPFailures.length > 0) {
    throw new Error(`Unexpected browser HTTP failures: ${JSON.stringify(unexpectedHTTPFailures)}`);
  }
  if (report.consoleErrors.length > 0) {
    throw new Error(`Unexpected browser console errors: ${JSON.stringify(report.consoleErrors)}`);
  }
  if (report.browserErrors.length > 0) {
    throw new Error(`Unexpected browser page errors: ${JSON.stringify(report.browserErrors)}`);
  }
}

async function runBrowserAccessLoop(baseURL, child) {
  recordPhase("browser.loop.start", {
    iterations: browserIterations,
    browserReadyTimeoutMs,
    mode: reuseBrowserPage ? "same-page" : "new-page",
  });
  const browser = await launchBrowser();
  const latencies = [];
  try {
    if (reuseBrowserPage) {
      await runSamePageBrowserAccessLoop(browser, baseURL, child, latencies);
    } else {
      await warmBrowserRuntime(browser, baseURL);
      await runNewPageBrowserAccessLoop(browser, baseURL, child, latencies);
    }
  } finally {
    await browser.close();
  }

  report.browserLatency = summarizeLatencies(latencies);
  recordPhase("browser.loop.passed", report.browserLatency);
}

async function runSamePageBrowserAccessLoop(browser, baseURL, child, latencies) {
  const page = await browser.newPage();
  attachPageDiagnostics(page, "chromium");
  try {
    recordPhase("browser.warmup.start", { startupTimeoutMs, mode: "same-page" });
    await openTestPage(page, `${baseURL}${testPath}?stress=warmup`, startupTimeoutMs);
    report.browserWarmup = await browserState(page);
    recordPhase("browser.warmup.passed");

    for (let iteration = 0; iteration < browserIterations; iteration += 1) {
      assertServerRunning(child, `browser iteration ${iteration}`);
      const startedAt = performance.now();
      await openTestPage(page, `${baseURL}${testPath}?stress=browser-${iteration}`, browserReadyTimeoutMs);
      const state = await browserState(page);
      if (!state.bodyHasExpectedText) {
        throw new Error(`browser iteration ${iteration} reached an invalid runtime state: ${JSON.stringify(state)}`);
      }
      const elapsedMs = performance.now() - startedAt;
      latencies.push(elapsedMs);
      rememberBrowserSample({
        iteration,
        elapsedMs: Math.round(elapsedMs),
        mode: "same-page",
        state,
      });
    }
  } finally {
    await Promise.race([
      page.close({ runBeforeUnload: false }).catch(() => {}),
      delay(3_000),
    ]);
  }
}

async function runNewPageBrowserAccessLoop(browser, baseURL, child, latencies) {
  for (let iteration = 0; iteration < browserIterations; iteration += 1) {
    assertServerRunning(child, `browser iteration ${iteration}`);
    const page = await browser.newPage();
    attachPageDiagnostics(page, "chromium");
    const startedAt = performance.now();
    try {
      await openTestPage(page, `${baseURL}${testPath}?stress=browser-${iteration}`, browserReadyTimeoutMs);
      const state = await browserState(page);
      if (!state.bodyHasExpectedText) {
        throw new Error(`browser iteration ${iteration} reached an invalid runtime state: ${JSON.stringify(state)}`);
      }
      const elapsedMs = performance.now() - startedAt;
      latencies.push(elapsedMs);
      rememberBrowserSample({
        iteration,
        elapsedMs: Math.round(elapsedMs),
        mode: "new-page",
        state,
      });
    } finally {
      await Promise.race([
        page.close({ runBeforeUnload: false }).catch(() => {}),
        delay(3_000),
      ]);
    }
  }
}

async function warmBrowserRuntime(browser, baseURL) {
  recordPhase("browser.warmup.start", { startupTimeoutMs });
  const page = await browser.newPage();
  attachPageDiagnostics(page, "chromium");
  try {
    await openTestPage(page, `${baseURL}${testPath}?stress=warmup`, startupTimeoutMs);
    report.browserWarmup = await browserState(page);
  } finally {
    await Promise.race([
      page.close({ runBeforeUnload: false }).catch(() => {}),
      delay(3_000),
    ]);
  }
  recordPhase("browser.warmup.passed");
}

async function openTestPage(page, url, timeoutMs) {
  await page.goto(url, {
    waitUntil: "domcontentloaded",
    timeout: timeoutMs,
  });
  await page.waitForFunction(
    (expectedText) => document.body?.textContent?.includes(expectedText)
      && !!globalThis.__swiftWebDevReload?.eventSource
      && globalThis.__swiftWebDevReload?.lastError == null,
    expectedPageText,
    { timeout: timeoutMs }
  );
}

async function browserState(page) {
  return await page.evaluate((expectedText) => {
    const bodyText = document.body?.textContent ?? "";
    return {
      title: document.title,
      devReloadReadyState: globalThis.__swiftWebDevReload?.eventSource?.readyState ?? null,
      lastDevReloadError: globalThis.__swiftWebDevReload?.lastError ?? null,
      bodyHasExpectedText: bodyText.includes(expectedText),
      bodyTextLength: bodyText.length,
    };
  }, expectedPageText);
}

function rememberBrowserSample(sample) {
  report.browserSamples.push(sample);
  if (report.browserSamples.length > 12) {
    report.browserSamples.splice(0, report.browserSamples.length - 12);
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

let devServer;
let temporaryRoot;

try {
  if (!existsSync(exampleAppRoot)) {
    throw new Error(`HelloWorld example package was not found: ${exampleAppRoot}`);
  }
  if (!existsSync(swiftHTMLRoot)) {
    throw new Error(`Local swift-html package was not found: ${swiftHTMLRoot}`);
  }
  const temporaryParent = path.join(swiftWebRoot, ".swiftweb", "browser-e2e");
  await mkdir(temporaryParent, { recursive: true });
  temporaryRoot = await mkdtemp(path.join(temporaryParent, "page-access-stress-"));
  const appRoot = await prepareAppCopy(temporaryRoot);
  const scratchRoot = path.join(temporaryRoot, ".swiftweb", "dev");
  const port = await availablePort();
  const baseURL = `http://127.0.0.1:${port}`;
  report.baseURL = baseURL;
  report.configuration = {
    httpIterations,
    httpConcurrency,
    browserIterations,
    requestTimeoutMs,
    browserReadyTimeoutMs,
    maxHTTPP95Ms,
    reuseBrowserPage,
  };

  recordPhase("server.start", { baseURL });
  devServer = await launchDevServer(appRoot, scratchRoot, port);
  await waitForHTTP(`${baseURL}${testPath}`, Date.now() + startupTimeoutMs, devServer);
  recordPhase("server.ready");

  await runHTTPAccessLoop(baseURL, devServer);
  await runBrowserAccessLoop(baseURL, devServer);
  assertNoUnexpectedBrowserDiagnostics();
  assertServerRunning(devServer, "final check");
  recordPhase("passed");
} catch (error) {
  report.error = String(error && error.stack ? error.stack : error);
  console.error(report.error);
  process.exitCode = 1;
} finally {
  await stopProcess(devServer);
  if (temporaryRoot) {
    await removeTemporaryRoot(temporaryRoot);
  }
  console.log(JSON.stringify(report, null, 2));
}
