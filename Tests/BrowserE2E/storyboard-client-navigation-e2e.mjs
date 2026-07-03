import { createRequire } from "node:module";
import { execFile, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { rm } from "node:fs/promises";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const require = createRequire(import.meta.url);
const execFileAsync = promisify(execFile);

if (process.env.SWIFTWEB_BROWSER_E2E !== "1") {
  console.log("Skipping SwiftWeb Storyboard browser E2E. Set SWIFTWEB_BROWSER_E2E=1 to run.");
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
const timeoutMs = Number(process.env.SWIFTWEB_E2E_TIMEOUT_MS || 600_000);
const report = {
  phases: [],
  consoleErrors: [],
  browserErrors: [],
  httpFailures: [],
  serverLogTail: [],
  wasmResponses: [],
  navigations: [],
};

function recordPhase(name, detail = {}) {
  const entry = {
    name,
    at: new Date().toISOString(),
    ...detail,
  };
  report.phases.push(entry);
  console.log(`[storyboard-navigation-e2e] ${name}`);
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

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForHTTP(url, deadline) {
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html" },
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

async function launchStoryboardServer(port) {
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
      "storyboard",
      "--package-path",
      swiftWebRoot,
      "--host",
      "127.0.0.1",
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
    if (report.serverLogTail.length > 160) {
      report.serverLogTail.splice(0, report.serverLogTail.length - 160);
    }
    for (const line of lines) {
      console.log(`[sweb storyboard] ${line}`);
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
    if (url.pathname.endsWith(".wasm")) {
      const entry = {
        browser: browserName,
        url: response.url(),
        path: url.pathname,
        status: response.status(),
        at: new Date().toISOString(),
      };
      report.wasmResponses.push(entry);
    }
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

async function runtimeState(page) {
  return await page.evaluate(() => {
    const metrics = globalThis.__swiftWebWasmRuntimeMetrics || {};
    const events = metrics.events || [];
    const navigationEvents = events.filter((event) => String(event.name || "").startsWith("navigation."));
    return {
      href: location.href,
      pathname: location.pathname,
      hash: location.hash,
      title: document.title,
      h1: document.querySelector("h1")?.textContent || null,
      allCurrentPageLinks: Array.from(document.querySelectorAll("a[aria-current='page']")).map((anchor) => ({
        href: anchor.getAttribute("href"),
        text: anchor.textContent.trim(),
      })),
      selectedLinks: Array.from(document.querySelectorAll("[role='navigation'] a[aria-current='page']")).map((anchor) => ({
        href: anchor.getAttribute("href"),
        text: anchor.textContent.trim(),
      })),
      ready: document.documentElement.getAttribute("data-wasm-ready"),
      colorScheme: document.body?.getAttribute("data-color-scheme") || null,
      selectedSchemeChips: Array.from(document.querySelectorAll("[data-scheme-chip].swui-storyboard-chip-selected"))
        .map((chip) => chip.getAttribute("data-scheme-chip")),
      phase: document.documentElement.getAttribute("data-wasm-phase"),
      status: globalThis.__swiftWebWasmRuntimeStatus || null,
      summary: metrics.summary || {},
      instantiateCount: events.filter((event) => event.name === "bundle.instantiate.start").length,
      navigationEvents,
      lastNavigationEvents: navigationEvents.slice(-4),
      runtimeSummaryText: document.querySelector("[data-swiftweb-runtime-summary]")?.textContent || "",
      runtimeLogText: document.querySelector("[data-swiftweb-runtime-log]")?.textContent || "",
      marker: globalThis.__swiftWebE2EMarker || null,
    };
  });
}

async function waitForRuntimeReady(page) {
  await page.waitForFunction(
    () => document.documentElement.getAttribute("data-wasm-ready") === "true"
      && globalThis.__swiftWebWasmRuntimeMetrics?.ready === true,
    undefined,
    { timeout: timeoutMs }
  );
}

async function waitForPath(page, path) {
  await page.waitForFunction(
    (expectedPath) => location.pathname === expectedPath
      && document.documentElement.getAttribute("data-wasm-ready") === "true"
      && globalThis.__swiftWebWasmRuntimeMetrics?.ready === true,
    path,
    { timeout: timeoutMs }
  );
}

async function assertRouteState(page, expected) {
  const state = await runtimeState(page);
  if (state.pathname !== expected.path || state.h1 !== expected.h1) {
    throw new Error(`Unexpected route state for ${expected.path}: ${JSON.stringify(state)}`);
  }
  const selectedHref = expected.selectedHref || expected.path;
  if (state.selectedLinks.length !== 1 || state.selectedLinks[0].href !== selectedHref) {
    throw new Error(`Selected sidebar link did not match ${selectedHref}: ${JSON.stringify({
      selectedLinks: state.selectedLinks,
      allCurrentPageLinks: state.allCurrentPageLinks,
    })}`);
  }
  if (!state.runtimeSummaryText.includes("phase=ready") || state.runtimeLogText.length === 0) {
    throw new Error(`Storyboard runtime log panel did not publish ready diagnostics: ${JSON.stringify({
      runtimeSummaryText: state.runtimeSummaryText,
      runtimeLogText: state.runtimeLogText,
    })}`);
  }
  return state;
}

async function selectStoryboardScheme(page, scheme) {
  const clicked = await page.evaluate((value) => {
    const chip = document.querySelector(`[data-scheme-chip="${value}"]`);
    if (!chip) {
      return false;
    }
    chip.click();
    return true;
  }, scheme);
  if (!clicked) {
    throw new Error(`Scheme chip ${scheme} was not found.`);
  }
  await page.waitForFunction(
    (value) => document.body
      && document.body.getAttribute("data-color-scheme") === value
      && document.cookie.includes(`swui-storyboard-scheme=${value}`)
      && Array.from(document.querySelectorAll("[data-scheme-chip].swui-storyboard-chip-selected"))
        .some((chip) => chip.getAttribute("data-scheme-chip") === value),
    scheme,
    { timeout: timeoutMs }
  );
}

function assertStoryboardScheme(state, scheme, context) {
  if (state.colorScheme !== scheme || !state.selectedSchemeChips.includes(scheme)) {
    throw new Error(`${context} did not preserve Storyboard scheme ${scheme}: ${JSON.stringify({
      colorScheme: state.colorScheme,
      selectedSchemeChips: state.selectedSchemeChips,
    })}`);
  }
}

function assertNoRuntimeRestart(before, after, context) {
  if (after.marker !== before.marker) {
    throw new Error(`${context} caused a full page reload: marker changed from ${before.marker} to ${after.marker}`);
  }
  if (after.instantiateCount !== before.instantiateCount) {
    throw new Error(`${context} instantiated WASM again: before=${before.instantiateCount} after=${after.instantiateCount}`);
  }
}

async function clickSidebarRoute(page, route) {
  const before = await runtimeState(page);
  const wasmResponseCount = report.wasmResponses.length;
  const navigationCount = before.navigationEvents.length;
  const startedAt = Date.now();
  const clickResult = await page.evaluate(({ path, label }) => {
    const candidates = Array.from(document.querySelectorAll("a[href]"))
      .filter((anchor) => anchor.getAttribute("href") === path && anchor.textContent.trim() === label)
      .map((anchor, index) => {
        const rect = anchor.getBoundingClientRect();
        return {
          anchor,
          index,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          text: anchor.textContent.trim(),
        };
      });
    const sidebarCandidate = candidates.find((candidate) =>
      candidate.left < 360 &&
      candidate.width > 0 &&
      candidate.height > 0
    );
    if (!sidebarCandidate) {
      return {
        clicked: false,
        candidates: candidates.map(({ anchor, ...candidate }) => candidate),
      };
    }
    sidebarCandidate.anchor.click();
    return {
      clicked: true,
      index: sidebarCandidate.index,
      candidates: candidates.map(({ anchor, ...candidate }) => candidate),
    };
  }, { path: route.path, label: route.label });
  if (!clickResult.clicked) {
    throw new Error(`Sidebar link ${route.path} was not found in the sidebar: ${JSON.stringify(clickResult.candidates)}`);
  }
  await waitForPath(page, route.path);
  const after = await assertRouteState(page, route);
  const newNavigationEvents = after.navigationEvents.slice(navigationCount);
  if (!newNavigationEvents.some((event) => event.name === "navigation.complete" && event.href.endsWith(route.path))) {
    throw new Error(`Client navigation completion was not recorded for ${route.path}: ${JSON.stringify(newNavigationEvents)}`);
  }
  if (!after.runtimeLogText.includes("navigation.complete") || !after.runtimeLogText.includes(route.path)) {
    throw new Error(`Storyboard runtime log panel did not show navigation completion for ${route.path}: ${after.runtimeLogText}`);
  }
  if (report.wasmResponses.length !== wasmResponseCount) {
    throw new Error(`Client navigation fetched WASM again for ${route.path}: ${JSON.stringify(report.wasmResponses.slice(wasmResponseCount))}`);
  }
  assertNoRuntimeRestart(before, after, `Sidebar navigation to ${route.path}`);
  const result = {
    path: route.path,
    elapsedMs: Date.now() - startedAt,
    navigationEvents: newNavigationEvents,
    instantiateCount: after.instantiateCount,
  };
  report.navigations.push(result);
  return after;
}

async function runBrowserAssertions(baseURL) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    attachPageDiagnostics(page, "chromium");
    recordPhase("browser.goto");
    await page.goto(`${baseURL}/storyboard`, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await waitForRuntimeReady(page);
    await page.evaluate(() => {
      globalThis.__swiftWebE2EMarker = crypto.randomUUID();
    });

    const initial = await assertRouteState(page, {
      path: "/storyboard",
      h1: "Text",
      selectedHref: "/storyboard/typography",
    });
    if (initial.instantiateCount !== 1) {
      throw new Error(`Initial Storyboard load should instantiate the eager runtime once: ${JSON.stringify(initial)}`);
    }
    report.initialRuntime = initial;

    recordPhase("theme.light-cookie");
    await selectStoryboardScheme(page, "light");
    assertStoryboardScheme(await runtimeState(page), "light", "Light scheme selection");

    recordPhase("navigation.sidebar");
    const grid = await clickSidebarRoute(page, { path: "/storyboard/grid", h1: "Grid", label: "Grid" });
    assertStoryboardScheme(grid, "light", "Grid navigation");
    const typography = await clickSidebarRoute(page, { path: "/storyboard/typography", h1: "Text", label: "Text" });
    assertStoryboardScheme(typography, "light", "Typography navigation");
    const style = await clickSidebarRoute(page, { path: "/storyboard/style", h1: "Style", label: "Style" });
    assertStoryboardScheme(style, "light", "Style navigation");
    assertNoRuntimeRestart(initial, grid, "Grid navigation");
    assertNoRuntimeRestart(grid, typography, "Typography navigation");
    assertNoRuntimeRestart(typography, style, "Style navigation");

    recordPhase("navigation.history");
    const beforeBack = await runtimeState(page);
    await page.evaluate(() => history.back());
    await waitForPath(page, "/storyboard/typography");
    const afterBack = await assertRouteState(page, { path: "/storyboard/typography", h1: "Text" });
    assertStoryboardScheme(afterBack, "light", "Back navigation");
    assertNoRuntimeRestart(beforeBack, afterBack, "Back navigation");

    await page.evaluate(() => history.forward());
    await waitForPath(page, "/storyboard/style");
    const afterForward = await assertRouteState(page, { path: "/storyboard/style", h1: "Style" });
    assertStoryboardScheme(afterForward, "light", "Forward navigation");
    assertNoRuntimeRestart(afterBack, afterForward, "Forward navigation");
    const popstateEvents = afterForward.navigationEvents.filter((event) => event.history === "popstate");
    if (popstateEvents.length < 2) {
      throw new Error(`Back/forward did not record popstate navigation events: ${JSON.stringify(afterForward.navigationEvents.slice(-8))}`);
    }

    recordPhase("navigation.hash-native");
    const beforeHash = await runtimeState(page);
    const hashClickResult = await page.evaluate(() => {
      const candidates = Array.from(document.querySelectorAll("a[href='#preview']"))
        .map((anchor, index) => {
          const rect = anchor.getBoundingClientRect();
          return {
            anchor,
            index,
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            text: anchor.textContent.trim(),
          };
        });
      const visible = candidates.find((candidate) => candidate.width > 0 && candidate.height > 0);
      if (!visible) {
        return {
          clicked: false,
          candidates: candidates.map(({ anchor, ...candidate }) => candidate),
        };
      }
      visible.anchor.click();
      return {
        clicked: true,
        index: visible.index,
        candidates: candidates.map(({ anchor, ...candidate }) => candidate),
      };
    });
    if (!hashClickResult.clicked) {
      throw new Error(`Preview hash link was not visible: ${JSON.stringify(hashClickResult.candidates)}`);
    }
    await page.waitForFunction(() => location.hash === "#preview", undefined, { timeout: timeoutMs });
    const afterHash = await runtimeState(page);
    assertNoRuntimeRestart(beforeHash, afterHash, "Hash navigation");
    if (afterHash.navigationEvents.length !== beforeHash.navigationEvents.length) {
      throw new Error(`Hash link should remain native and not record client navigation: ${JSON.stringify(afterHash.navigationEvents.slice(-4))}`);
    }

    recordPhase("navigation.external-native");
    const beforeExternal = await runtimeState(page);
    await page.evaluate(() => {
      const anchor = document.createElement("a");
      anchor.id = "swiftweb-e2e-external-link";
      anchor.href = "https://example.com/";
      anchor.target = "_blank";
      anchor.textContent = "External E2E";
      document.body.appendChild(anchor);
    });
    const externalClick = await page.evaluate(() => {
      const anchor = document.querySelector("#swiftweb-e2e-external-link");
      if (!anchor) {
        return { dispatched: false };
      }
      const event = new MouseEvent("click", {
        bubbles: true,
        cancelable: true,
        button: 0,
        view: window,
      });
      const dispatchResult = anchor.dispatchEvent(event);
      return {
        dispatched: true,
        defaultPrevented: event.defaultPrevented,
        dispatchResult,
      };
    });
    if (!externalClick.dispatched || externalClick.defaultPrevented || externalClick.dispatchResult === false) {
      throw new Error(`External target link should not be intercepted: ${JSON.stringify(externalClick)}`);
    }
    const afterExternal = await runtimeState(page);
    assertNoRuntimeRestart(beforeExternal, afterExternal, "External target navigation");
    if (afterExternal.navigationEvents.length !== beforeExternal.navigationEvents.length) {
      throw new Error(`External target link should remain native and not record client navigation: ${JSON.stringify(afterExternal.navigationEvents.slice(-4))}`);
    }

    report.finalRuntime = afterExternal;
  } finally {
    await browser.close();
  }
}

let devServer;

try {
  const port = await availablePort();
  const baseURL = `http://127.0.0.1:${port}`;
  report.baseURL = baseURL;

  recordPhase("server.start", { baseURL });
  devServer = await launchStoryboardServer(port);
  await waitForHTTP(`${baseURL}/storyboard`, Date.now() + timeoutMs);
  recordPhase("server.ready");

  await runBrowserAssertions(baseURL);
  assertNoUnexpectedBrowserDiagnostics();
  recordPhase("passed");
} catch (error) {
  report.error = String(error && error.stack ? error.stack : error);
  console.error(report.error);
  process.exitCode = 1;
} finally {
  await stopProcess(devServer);
  if (process.env.SWIFTWEB_E2E_KEEP_STORYBOARD === "1") {
    report.keptStoryboard = path.join(swiftWebRoot, ".swiftweb", "storyboard");
  } else {
    await rm(path.join(swiftWebRoot, ".swiftweb", "storyboard"), { recursive: true, force: true });
  }
  const output = JSON.stringify(report, null, 2);
  console.log(output);
}
