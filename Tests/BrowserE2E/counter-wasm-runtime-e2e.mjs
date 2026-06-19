import { createRequire } from "node:module";
import { execFile, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const require = createRequire(import.meta.url);
const execFileAsync = promisify(execFile);

if (process.env.SWIFTWEB_BROWSER_E2E !== "1") {
  console.log("Skipping SwiftWeb browser E2E. Set SWIFTWEB_BROWSER_E2E=1 to run.");
  process.exit(0);
}

let chromium;
let webkit;
try {
  ({ chromium, webkit } = require("playwright"));
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
  httpFailures: [],
  serverLogTail: [],
  wasmResponses: [],
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
      return name !== ".build" && name !== ".swiftweb";
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

  await writeFile(
    path.join(appRoot, "Sources", "CounterApp", "ClientDeferredCounter.swift"),
    `import SwiftHTML
import SwiftWebUI

public struct ClientDeferredCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .interaction
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("deferred-counter")) {
            VStack(spacing: .large) {
                Heading("Deferred Client Counter")
                Text(
                    "This counter hydrates only after user interaction.",
                    tone: .muted
                )
                ValueDisplay(label: "Deferred value", value: value)
                Button("Increment deferred") {
                    value += 1
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
`
  );

  await writeFile(
    path.join(appRoot, "Sources", "CounterApp", "ClientLoadingPolicyCounters.swift"),
    `import SwiftHTML
import SwiftWebUI

public struct ClientVisibleCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .visible
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("visible-counter")) {
            VStack(spacing: .large) {
                Heading("Visible Client Counter")
                Text("This counter hydrates when it enters the viewport.", tone: .muted)
                ValueDisplay(label: "Visible value", value: value)
                Button("Increment visible") {
                    value += 1
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct ClientIdleCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .idle
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("idle-counter")) {
            VStack(spacing: .large) {
                Heading("Idle Client Counter")
                Text("This counter hydrates during the browser idle stage.", tone: .muted)
                ValueDisplay(label: "Idle value", value: value)
                Button("Increment idle") {
                    value += 1
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct ClientManualCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("manual-counter")) {
            VStack(spacing: .large) {
                Heading("Manual Client Counter")
                Text("This counter hydrates only when the runtime explicitly loads its bundle.", tone: .muted)
                ValueDisplay(label: "Manual value", value: value)
                Button("Increment manual") {
                    value += 1
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct ClientSharedBadgeA: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .shared("badges")
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("shared-badge-a")) {
            VStack(spacing: .small) {
                Heading("Shared Badge A")
                ValueDisplay(label: "Badge A", value: value)
                Button("Increment shared A") {
                    value += 1
                }
            }
        }
    }
}

public struct ClientSharedBadgeB: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .shared("badges")
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("shared-badge-b")) {
            VStack(spacing: .small) {
                Heading("Shared Badge B")
                ValueDisplay(label: "Badge B", value: value)
                Button("Increment shared B") {
                    value += 1
                }
            }
        }
    }
}

public struct ClientNamedToolA: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .named("tools")
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("named-tool-a")) {
            VStack(spacing: .small) {
                Heading("Named Tool A")
                ValueDisplay(label: "Tool A", value: value)
                Button("Increment named A") {
                    value += 1
                }
            }
        }
    }
}

public struct ClientNamedToolB: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .named("tools")
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("named-tool-b")) {
            VStack(spacing: .small) {
                Heading("Named Tool B")
                ValueDisplay(label: "Tool B", value: value)
                Button("Increment named B") {
                    value += 1
                }
            }
        }
    }
}
`
  );

  const counterPageFile = path.join(appRoot, "Sources", "CounterApp", "Routes", "CounterPage.swift");
  const counterPage = await readFile(counterPageFile, "utf8");
  let updatedCounterPage = counterPage.replace(
    "ClientCounter()\n\n                Card(.class(\"server-counter\"))",
    "ClientCounter()\n                ClientDeferredCounter()\n\n                Card(.class(\"server-counter\"))"
  );
  const insertedDeferredCounter = updatedCounterPage !== counterPage;
  updatedCounterPage = updatedCounterPage.replace(
    "            Link(\"Reload page\", href: \"/counter\")",
    `            Card(.class("visible-policy-spacer")) {
                VStack(spacing: .small) {
                    Heading("Loading Policy E2E Spacer")
                    Text("The visible counter sits below this spacer so IntersectionObserver is required.")
                }
            }
            .style {
                .minHeight("960px")
            }

            ClientVisibleCounter()
            ClientIdleCounter()
            ClientManualCounter()
            ClientSharedBadgeA()
            ClientSharedBadgeB()
            ClientNamedToolA()
            ClientNamedToolB()

            Link("Reload page", href: "/counter")`
  );
  const insertedLoadingPolicyCounters = updatedCounterPage.includes("ClientManualCounter()");
  if (!insertedDeferredCounter || !insertedLoadingPolicyCounters) {
    throw new Error("Failed to inject E2E ClientComponents into CounterPage.swift.");
  }
  await writeFile(counterPageFile, updatedCounterPage);
  return appRoot;
}

async function launchDevServer(appRoot, scratchRoot, port) {
  const swiftWebExecutable = await resolveSwiftWebExecutable();
  const wasmSwiftSDK = process.env.SWIFT_WEB_WASM_SDK || "swift-6.3.1-RELEASE_wasm";
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
      console.log(`[swift-web dev] ${line}`);
    }
  };
  child.stdout.on("data", appendLog);
  child.stderr.on("data", appendLog);

  child.once("exit", (code, signal) => {
    report.serverExit = { code, signal };
  });

  report.swiftWebExecutable = swiftWebExecutable;
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
      "swift-web",
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
    throw new Error("Unable to resolve swift-web binary path.");
  }

  const executable = path.join(binPath, "swift-web");
  if (!existsSync(executable)) {
    throw new Error(`Resolved swift-web executable does not exist: ${executable}`);
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

async function processLinesMatching(pattern) {
  if (process.platform !== "darwin" && process.platform !== "linux") {
    return [];
  }
  try {
    const { stdout } = await execFileAsync("pgrep", ["-fl", pattern]);
    return stdout
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
      .filter((line) => !line.includes("pgrep -fl"));
  } catch (error) {
    if (error && error.code === 1) {
      return [];
    }
    throw error;
  }
}

async function waitForNoProcessLines(pattern, timeout = 10_000) {
  const deadline = Date.now() + timeout;
  let remainingProcesses = [];
  while (Date.now() < deadline) {
    remainingProcesses = await processLinesMatching(pattern);
    if (remainingProcesses.length === 0) {
      return [];
    }
    await delay(250);
  }
  return remainingProcesses;
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

async function runWebKitSmoke(baseURL) {
  if (!webkit) {
    const reason = "Playwright WebKit is not available in this installation.";
    report.webkitSmoke = { skipped: true, reason };
    recordPhase("webkit.smoke.skipped", { reason });
    if (process.env.SWIFTWEB_E2E_REQUIRE_WEBKIT === "1") {
      throw new Error(reason);
    }
    return;
  }

  const headless = process.env.SWIFTWEB_E2E_HEADFUL !== "1";
  let browser;
  try {
    browser = await webkit.launch({ headless });
  } catch (error) {
    const reason = String(error && error.message ? error.message : error);
    report.webkitSmoke = { skipped: true, reason };
    recordPhase("webkit.smoke.skipped", { reason });
    if (process.env.SWIFTWEB_E2E_REQUIRE_WEBKIT === "1") {
      throw error;
    }
    return;
  }

  try {
    const page = await browser.newPage();
    attachPageDiagnostics(page, "webkit");
    recordPhase("webkit.smoke.goto");
    await page.goto(`${baseURL}/counter`, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await page.waitForFunction(
      () => document.documentElement.getAttribute("data-wasm-ready") === "true",
      undefined,
      { timeout: timeoutMs }
    );
    await expectCardValue(page, ".client-counter", 0);
    report.webkitSmoke = {
      skipped: false,
      runtime: await browserRuntimeState(page),
    };
    recordPhase("webkit.smoke.passed");
  } finally {
    await browser.close();
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

function unexpectedServerLogNoise() {
  const patterns = [
    /CancellationError\(\)/,
    /stream ended at an unexpected time/i,
    /I\/O on closed channel/i,
    /FSEventStreamScheduleWithRunLoop/,
  ];
  return report.serverLogTail.filter((line) => patterns.some((pattern) => pattern.test(line)));
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

async function runtimeManifestSnapshot(page) {
  return await page.evaluate(() => {
    const rawValue = (value) => {
      if (!value) {
        return null;
      }
      return typeof value === "string" ? value : value.rawValue;
    };
    const runtime = window.__swiftWebWasmRuntime;
    const manifest = runtime?.manifest || {};
    const components = (manifest.components || []).map((component) => ({
      componentID: rawValue(component.componentID),
      typeName: component.typeName,
      bundleID: rawValue(component.bundleID),
      loadPolicy: component.loadPolicy,
      stateSchemaHash: component.stateSchemaHash || null,
      environmentSchemaHash: component.environmentSchemaHash || null,
    }));
    const bundles = (manifest.bundles || []).map((bundle) => ({
      id: rawValue(bundle.id),
      assetPath: bundle.asset?.path || null,
      loadPolicy: bundle.loadPolicy || null,
      components: (bundle.components || []).map(rawValue),
    }));
    const loadedBundleIDs = window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || [];
    return { components, bundles, loadedBundleIDs };
  });
}

function componentBySuffix(snapshot, suffix) {
  const component = snapshot.components.find((record) => record.typeName.endsWith(suffix));
  if (!component) {
    throw new Error(`ClientComponent ${suffix} was not present in manifest: ${JSON.stringify(snapshot.components)}`);
  }
  return component;
}

function bundleForComponent(snapshot, component) {
  const bundle = snapshot.bundles.find((record) => record.id === component.bundleID);
  if (!bundle || !bundle.assetPath) {
    throw new Error(`Bundle asset was not present for ${component.typeName}: ${JSON.stringify(snapshot.bundles)}`);
  }
  return bundle;
}

async function runBrowserAssertions(baseURL, appRoot) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    const wasmResponses = [];
    attachPageDiagnostics(page, "chromium");
    page.on("response", (response) => {
      const url = new URL(response.url());
      if (url.pathname.endsWith(".wasm")) {
        const entry = {
          url: response.url(),
          path: url.pathname,
          status: response.status(),
          at: new Date().toISOString(),
        };
        wasmResponses.push(entry);
        report.wasmResponses.push(entry);
      }
    });
    recordPhase("browser.goto");
    await page.goto(`${baseURL}/counter`, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await page.waitForFunction(
      () => document.documentElement.getAttribute("data-wasm-ready") === "true",
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
      loadedAttribute: document.documentElement.getAttribute("data-wasm-loaded"),
    }));
    if (!runtime.status || runtime.status.ready !== true) {
      throw new Error(`WASM runtime did not report ready: ${JSON.stringify(runtime.status)}`);
    }
    if (!runtime.metrics || !Array.isArray(runtime.metrics.bundles) || runtime.metrics.bundles.length === 0) {
      throw new Error("WASM runtime metrics did not record any loaded bundle.");
    }
    if (!String(runtime.loadedAttribute || "").includes("counter-app-wasm-runtime")) {
      throw new Error(`counter-app-wasm-runtime was not loaded: ${runtime.loadedAttribute || ""}`);
    }
    report.initialRuntime = runtime;
    recordPhase("wasm.ready", {
      loaded: runtime.loadedAttribute,
      bytes: runtime.metrics.summary && runtime.metrics.summary.totalWasmBytes,
    });

    const splitSnapshot = await runtimeManifestSnapshot(page);
    const deferredComponent = componentBySuffix(splitSnapshot, "ClientDeferredCounter");
    if (deferredComponent.loadPolicy !== "interaction") {
      throw new Error(`Deferred ClientComponent should use interaction policy: ${JSON.stringify(deferredComponent)}`);
    }
    if (splitSnapshot.loadedBundleIDs.includes(deferredComponent.bundleID)) {
      throw new Error(`Deferred bundle loaded during initial eager phase: ${JSON.stringify(splitSnapshot)}`);
    }
    const deferredBundle = bundleForComponent(splitSnapshot, deferredComponent);
    if (wasmResponses.some((response) => response.path === deferredBundle.assetPath)) {
      throw new Error(`Deferred bundle was fetched before interaction: ${deferredBundle.assetPath}`);
    }
    const visibleComponent = componentBySuffix(splitSnapshot, "ClientVisibleCounter");
    const idleComponent = componentBySuffix(splitSnapshot, "ClientIdleCounter");
    const manualComponent = componentBySuffix(splitSnapshot, "ClientManualCounter");
    const sharedBadgeA = componentBySuffix(splitSnapshot, "ClientSharedBadgeA");
    const sharedBadgeB = componentBySuffix(splitSnapshot, "ClientSharedBadgeB");
    const namedToolA = componentBySuffix(splitSnapshot, "ClientNamedToolA");
    const namedToolB = componentBySuffix(splitSnapshot, "ClientNamedToolB");
    if (visibleComponent.loadPolicy !== "visible") {
      throw new Error(`Visible component should use visible policy: ${JSON.stringify(visibleComponent)}`);
    }
    if (idleComponent.loadPolicy !== "idle") {
      throw new Error(`Idle component should use idle policy: ${JSON.stringify(idleComponent)}`);
    }
    if (manualComponent.loadPolicy !== "manual") {
      throw new Error(`Manual component should use manual policy: ${JSON.stringify(manualComponent)}`);
    }
    if (sharedBadgeA.bundleID !== sharedBadgeB.bundleID || !sharedBadgeA.bundleID.startsWith("shared-badges")) {
      throw new Error(`Shared components did not resolve to one shared bundle: ${JSON.stringify([sharedBadgeA, sharedBadgeB])}`);
    }
    if (namedToolA.bundleID !== namedToolB.bundleID || !namedToolA.bundleID.startsWith("named-tools")) {
      throw new Error(`Named components did not resolve to one named bundle: ${JSON.stringify([namedToolA, namedToolB])}`);
    }
    const visibleBundle = bundleForComponent(splitSnapshot, visibleComponent);
    const idleBundle = bundleForComponent(splitSnapshot, idleComponent);
    const manualBundle = bundleForComponent(splitSnapshot, manualComponent);
    const sharedBundle = bundleForComponent(splitSnapshot, sharedBadgeA);
    const namedBundle = bundleForComponent(splitSnapshot, namedToolA);
    const delayedBundleIDs = [
      visibleComponent.bundleID,
      manualComponent.bundleID,
      sharedBadgeA.bundleID,
      namedToolA.bundleID,
    ];
    const prematurelyLoaded = delayedBundleIDs.filter((bundleID) => splitSnapshot.loadedBundleIDs.includes(bundleID));
    if (prematurelyLoaded.length > 0) {
      throw new Error(`Delayed bundles loaded during initial eager phase: ${JSON.stringify(prematurelyLoaded)}`);
    }
    const delayedAssetPaths = [visibleBundle, manualBundle, sharedBundle, namedBundle].map((bundle) => bundle.assetPath);
    const prematureFetches = wasmResponses.filter((response) => delayedAssetPaths.includes(response.path));
    if (prematureFetches.length > 0) {
      throw new Error(`Delayed bundle assets fetched before trigger: ${JSON.stringify(prematureFetches)}`);
    }
    report.splitInitial = {
      deferredComponent,
      deferredBundle,
      visibleComponent,
      visibleBundle,
      idleComponent,
      idleBundle,
      manualComponent,
      manualBundle,
      sharedBundle,
      namedBundle,
      loadedBundleIDs: splitSnapshot.loadedBundleIDs,
      wasmResponses: wasmResponses.slice(),
    };

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
    await expectCardValue(page, ".deferred-counter", 0);
    await expectCardValue(page, ".visible-counter", 0);
    await expectCardValue(page, ".idle-counter", 0);
    await expectCardValue(page, ".manual-counter", 0);
    await expectCardValue(page, ".shared-badge-a", 0);
    await expectCardValue(page, ".shared-badge-b", 0);
    await expectCardValue(page, ".named-tool-a", 0);
    await expectCardValue(page, ".named-tool-b", 0);

    recordPhase("idle.auto-load");
    await page.waitForFunction(
      (bundleID) => (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(bundleID),
      idleComponent.bundleID,
      { timeout: timeoutMs }
    );

    recordPhase("visible.viewport-load");
    const visibleBeforeScroll = await page.locator(".visible-counter").evaluate((element) => {
      const rect = element.getBoundingClientRect();
      return {
        top: rect.top,
        viewportHeight: window.innerHeight,
        loaded: (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(element.getAttribute("data-bundle")),
      };
    });
    if (visibleBeforeScroll.top <= visibleBeforeScroll.viewportHeight + 200) {
      throw new Error(`Visible counter setup is invalid; component is already near the viewport: ${JSON.stringify(visibleBeforeScroll)}`);
    }
    if (visibleBeforeScroll.loaded) {
      throw new Error(`Visible bundle loaded before entering viewport: ${JSON.stringify(visibleBeforeScroll)}`);
    }
    await page.locator(".visible-counter").scrollIntoViewIfNeeded();
    await page.waitForFunction(
      (bundleID) => (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(bundleID),
      visibleComponent.bundleID,
      { timeout: timeoutMs }
    );
    await page.locator(".visible-counter").getByRole("button", { name: "Increment visible" }).click();
    await expectCardValue(page, ".visible-counter", 1);
    await page.locator(".idle-counter").getByRole("button", { name: "Increment idle" }).click();
    await expectCardValue(page, ".idle-counter", 1);

    recordPhase("manual.explicit-load");
    await delay(1_000);
    const manualBeforeLoad = await runtimeManifestSnapshot(page);
    const autoLoadedManualBundles = [
      manualComponent.bundleID,
      sharedBadgeA.bundleID,
      namedToolA.bundleID,
    ].filter((bundleID) => manualBeforeLoad.loadedBundleIDs.includes(bundleID));
    if (autoLoadedManualBundles.length > 0) {
      throw new Error(`Manual bundles loaded before explicit request: ${JSON.stringify(autoLoadedManualBundles)}`);
    }
    await page.evaluate(
      async (bundleIDs) => {
        await window.__swiftWebWasmRuntime.loadBundles(bundleIDs);
      },
      [manualComponent.bundleID, sharedBadgeA.bundleID, namedToolA.bundleID]
    );
    for (const bundleID of [manualComponent.bundleID, sharedBadgeA.bundleID, namedToolA.bundleID]) {
      await page.waitForFunction(
        (loadedBundleID) => (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(loadedBundleID),
        bundleID,
        { timeout: timeoutMs }
      );
    }
    await page.locator(".manual-counter").getByRole("button", { name: "Increment manual" }).click();
    await page.locator(".shared-badge-b").getByRole("button", { name: "Increment shared B" }).click();
    await page.locator(".named-tool-a").getByRole("button", { name: "Increment named A" }).click();
    await expectCardValue(page, ".manual-counter", 1);
    await expectCardValue(page, ".shared-badge-b", 1);
    await expectCardValue(page, ".named-tool-a", 1);
    report.loadingPolicyAfterExplicitLoad = await runtimeManifestSnapshot(page);

    recordPhase("deferred.interaction-load");
    await page.locator(".deferred-counter").hover();
    await page.waitForFunction(
      (bundleID) => (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(bundleID),
      deferredComponent.bundleID,
      { timeout: timeoutMs }
    );
    const splitAfterInteraction = await page.evaluate((bundleID) => ({
      loadedBundleIDs: window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || [],
      metricEvents: (window.__swiftWebWasmRuntimeMetrics?.events || [])
        .filter((event) => JSON.stringify(event).includes(bundleID)),
    }), deferredComponent.bundleID);
    if (!wasmResponses.some((response) => response.path === deferredBundle.assetPath && response.status >= 200 && response.status < 300)) {
      throw new Error(`Deferred WASM asset was not fetched after interaction: ${deferredBundle.assetPath}`);
    }
    report.splitAfterInteraction = splitAfterInteraction;
    await page.locator(".deferred-counter").getByRole("button", { name: "Increment deferred" }).click();
    await expectCardValue(page, ".deferred-counter", 1);

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

    recordPhase("client.hmr.failure-rollback");
    await writeFile(clientCounterFile, `${updatedSource}

public let swiftWebE2EInjectedCompilerError =
`);
    await page.waitForFunction(
      () => {
        const applied = globalThis.__swiftWebDevReload?.lastAppliedEvent;
        return applied?.kind === "error" && String(applied.message || "").includes("Client WASM HMR failed");
      },
      undefined,
      { timeout: hmrTimeoutMs }
    );
    await expectCardValue(page, ".client-counter", 1);
    await expectCardValue(page, ".server-counter", 1);
    await expectCardValue(page, ".deferred-counter", 1);
    await expectCardValue(page, ".visible-counter", 1);
    await expectCardValue(page, ".idle-counter", 1);
    await expectCardValue(page, ".manual-counter", 1);
    await expectCardValue(page, ".shared-badge-b", 1);
    await expectCardValue(page, ".named-tool-a", 1);
    const markerAfterHMRFailure = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterHMRFailure !== initialMarker) {
      throw new Error("Failed ClientComponent HMR caused a full page reload.");
    }
    report.hmrFailure = await browserRuntimeState(page);
    if (!report.hmrFailure.devReload.lastAppliedEventKind || report.hmrFailure.devReload.lastAppliedEventKind !== "error") {
      throw new Error(`Failed ClientComponent HMR did not report an error event: ${JSON.stringify(report.hmrFailure)}`);
    }

    recordPhase("client.hmr.recover");
    await writeFile(clientCounterFile, updatedSource);
    await page.waitForFunction(
      () => {
        const applied = globalThis.__swiftWebDevReload?.lastAppliedEvent;
        return applied?.kind === "clientComponentUpdate"
          && document.body
          && document.body.textContent.includes("Client Counter HMR");
      },
      undefined,
      { timeout: hmrTimeoutMs }
    );
    await expectCardValue(page, ".client-counter", 1);
    await expectCardValue(page, ".server-counter", 1);

    recordPhase("server.hmr.page-change");
    const counterPageFile = path.join(appRoot, "Sources", "CounterApp", "Routes", "CounterPage.swift");
    const originalPageSource = await readFile(counterPageFile, "utf8");
    const updatedPageSource = originalPageSource.replace(
      "Each button posts a delta to Vapor. The value is read from server state on the next render.",
      "Server worker restart HMR applied. The value is read from the new Vapor worker."
    );
    if (updatedPageSource === originalPageSource) {
      throw new Error("Server HMR source marker was not found in CounterPage.swift.");
    }
    await writeFile(counterPageFile, updatedPageSource);
    await page.waitForFunction(
      () => document.body && document.body.textContent.includes("Server worker restart HMR applied."),
      undefined,
      { timeout: hmrTimeoutMs }
    );
    const markerAfterServerHMR = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterServerHMR !== initialMarker) {
      throw new Error("ServerComponent HMR caused a full page reload instead of a page patch.");
    }
    report.serverHMR = await browserRuntimeState(page);
    if (!["serverRestarted", "pagePatch"].includes(report.serverHMR.devReload.lastAppliedEventKind)) {
      throw new Error(`Server HMR did not report a server event: ${JSON.stringify(report.serverHMR)}`);
    }
    await expectCardValue(page, ".client-counter", 1);
    await expectCardValue(page, ".deferred-counter", 1);
    await expectCardValue(page, ".visible-counter", 1);
    await expectCardValue(page, ".idle-counter", 1);
    await expectCardValue(page, ".manual-counter", 1);
    await expectCardValue(page, ".shared-badge-b", 1);
    await expectCardValue(page, ".named-tool-a", 1);
    await expectCardValue(page, ".server-counter", 0);

    const finalValues = {
      client: await cardValue(page, ".client-counter"),
      server: await cardValue(page, ".server-counter"),
      deferred: await cardValue(page, ".deferred-counter"),
      visible: await cardValue(page, ".visible-counter"),
      idle: await cardValue(page, ".idle-counter"),
      manual: await cardValue(page, ".manual-counter"),
      sharedB: await cardValue(page, ".shared-badge-b"),
      namedA: await cardValue(page, ".named-tool-a"),
    };
    report.finalValues = finalValues;
    if (
      finalValues.client !== 1 ||
      finalValues.server !== 0 ||
      finalValues.deferred !== 1 ||
      finalValues.visible !== 1 ||
      finalValues.idle !== 1 ||
      finalValues.manual !== 1 ||
      finalValues.sharedB !== 1 ||
      finalValues.namedA !== 1
    ) {
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
  await runWebKitSmoke(baseURL);
  assertNoUnexpectedBrowserDiagnostics();
  recordPhase("passed");
} catch (error) {
  report.error = String(error && error.stack ? error.stack : error);
  console.error(report.error);
  process.exitCode = 1;
} finally {
  await stopProcess(devServer);
  await delay(200);
  const serverLogNoise = unexpectedServerLogNoise();
  report.unexpectedServerLogNoise = serverLogNoise;
  if (serverLogNoise.length > 0 && !report.error) {
    report.error = `SwiftWeb dev emitted unexpected shutdown log noise: ${serverLogNoise.join("\n")}`;
    process.exitCode = 1;
  }
  if (tempRoot) {
    try {
      const remainingProcesses = await waitForNoProcessLines(tempRoot);
      report.postStopProcessCheck = {
        pattern: tempRoot,
        remainingProcesses,
      };
      if (remainingProcesses.length > 0 && !report.error) {
        report.error = `SwiftWeb dev left child processes after stop: ${remainingProcesses.join("\n")}`;
        process.exitCode = 1;
      }
    } catch (error) {
      report.postStopProcessCheck = {
        error: String(error && error.message ? error.message : error),
      };
      if (!report.error) {
        report.error = `SwiftWeb dev post-stop process check failed: ${report.postStopProcessCheck.error}`;
        process.exitCode = 1;
      }
    }
  }
  if (tempRoot && process.env.SWIFTWEB_E2E_KEEP_TEMP !== "1") {
    await removeTemporaryRoot(tempRoot);
  }
  const output = JSON.stringify(report, null, 2);
  console.log(output);
}
