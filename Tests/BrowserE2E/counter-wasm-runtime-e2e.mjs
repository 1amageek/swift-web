import { createRequire } from "node:module";
import { execFile, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, rm, utimes, writeFile } from "node:fs/promises";
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
const expectedSwiftWebVersion = "0.11.0";
const expectedSwiftHTMLVersion = "0.15.0";
const exampleAppRoot = path.join(swiftWebRoot, "Examples", "CounterApp");
const timeoutMs = Number(process.env.SWIFTWEB_E2E_TIMEOUT_MS || 600_000);
const hmrTimeoutMs = Number(process.env.SWIFTWEB_E2E_HMR_TIMEOUT_MS || 300_000);
const bindHost = process.env.SWIFTWEB_E2E_BIND_HOST || "127.0.0.1";
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
      await response.arrayBuffer();
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

async function fetchDevStatus(baseURL) {
  const response = await fetch(`${baseURL}/__dev/status`, {
    headers: { Accept: "application/json" },
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Dev status returned HTTP ${response.status}: ${body}`);
  }
  return JSON.parse(body);
}

async function waitForDevStatus(baseURL, label, predicate, timeout = hmrTimeoutMs) {
  const deadline = Date.now() + timeout;
  let lastStatus = null;
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      lastStatus = await fetchDevStatus(baseURL);
      if (predicate(lastStatus)) {
        return lastStatus;
      }
    } catch (error) {
      lastError = error;
    }
    await delay(250);
  }
  throw new Error(
    `Timed out waiting for dev status ${label}: ${JSON.stringify({ lastStatus, lastError: String(lastError || "") })}`
  );
}

function isQuiescentDevStatus(status) {
  return status.phase === "ready"
    && status.stale === false
    && status.sourceFingerprint
    && status.sourceFingerprint === status.servingFingerprint
    && (status.buildingFingerprint === null || status.buildingFingerprint === undefined);
}

async function assertQuiescentFingerprintHeaders(baseURL) {
  const response = await fetch(`${baseURL}/counter`, {
    headers: { Accept: "text/html" },
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Counter page returned HTTP ${response.status}`);
  }
  const status = await fetchDevStatus(baseURL);
  const headers = {
    build: response.headers.get("x-swiftweb-dev-build"),
    source: response.headers.get("x-swiftweb-dev-source"),
    stale: response.headers.get("x-swiftweb-dev-stale"),
  };
  if (!isQuiescentDevStatus(status)
    || !headers.build
    || headers.build !== headers.source
    || headers.build !== status.sourceFingerprint
    || headers.stale !== "false") {
    throw new Error(`Dev fingerprints did not converge: ${JSON.stringify({ status, headers })}`);
  }
  return { status, headers, body };
}

async function verifyInitialBuildEdit(baseURL, appRoot) {
  recordPhase("reconciler.initial-build.waiting");
  const buildingStatus = await waitForDevStatus(
    baseURL,
    "initial server build",
    (status) => status.phase === "building"
      && status.buildingFingerprint
      && (status.servingFingerprint === null || status.servingFingerprint === undefined)
  );
  const counterPageFile = path.join(appRoot, "Sources", "CounterApp", "Routes", "CounterPage.swift");
  const originalSource = await readFile(counterPageFile, "utf8");
  const updatedSource = originalSource.replace(
    'Text("Server Counter").as(.h2)',
    'Text("Server Counter Initial Build Edit").as(.h2)'
  );
  if (updatedSource === originalSource) {
    throw new Error("Initial-build edit marker was not found in CounterPage.swift.");
  }
  await writeFile(counterPageFile, updatedSource);
  report.initialBuildEdit = { buildingStatus };
  recordPhase("reconciler.initial-build.edited");
}

async function verifyTouchDoesNotRebuild(baseURL, appRoot, tempRoot) {
  const before = await assertQuiescentFingerprintHeaders(baseURL);
  const workerBefore = await activeWorkerProcess(tempRoot);
  const transitionLogCount = report.serverLogTail.filter(
    (line) => line.includes("server worker") || line.includes("server restart")
  ).length;
  const sourceFile = path.join(appRoot, "Sources", "CounterApp", "ClientCounter.swift");
  const now = new Date();
  await utimes(sourceFile, now, now);
  await delay(3_500);
  const after = await assertQuiescentFingerprintHeaders(baseURL);
  const workerAfter = await activeWorkerProcess(tempRoot);
  const nextTransitionLogCount = report.serverLogTail.filter(
    (line) => line.includes("server worker") || line.includes("server restart")
  ).length;
  if (before.status.sourceFingerprint !== after.status.sourceFingerprint
    || transitionLogCount !== nextTransitionLogCount
    || workerBefore.pid !== workerAfter.pid) {
    throw new Error(
      `Touch-only change triggered a rebuild: ${JSON.stringify({ before, after, workerBefore, workerAfter, transitionLogCount, nextTransitionLogCount })}`
    );
  }
  report.touchVerification = {
    fingerprint: after.status.sourceFingerprint,
    workerPID: workerAfter.pid,
    transitionLogCount,
  };
  recordPhase("reconciler.touch.no-rebuild");
}

function parseProcessLine(line) {
  const match = line.match(/^(\d+)\s+(.+)$/);
  if (!match) {
    return null;
  }
  return { pid: Number(match[1]), command: match[2] };
}

async function activeWorkerProcess(tempRoot) {
  const matches = await workerProcesses(tempRoot);
  if (matches.length !== 1) {
    throw new Error(`Expected one active app-server-dev worker, found: ${JSON.stringify(matches)}`);
  }
  return matches[0];
}

async function workerProcesses(tempRoot) {
  return (await processLinesMatching(tempRoot))
    .map(parseProcessLine)
    .filter(Boolean)
    .filter((processInfo) => /(^|\/)app-server-dev(?:\s|$)/.test(processInfo.command));
}

async function waitForReplacementWorker(tempRoot, previousPID, timeout = hmrTimeoutMs) {
  const deadline = Date.now() + timeout;
  let lastMatches = [];
  while (Date.now() < deadline) {
    lastMatches = await workerProcesses(tempRoot);
    const replacement = lastMatches.find((processInfo) => processInfo.pid !== previousPID);
    if (replacement) {
      return replacement;
    }
    await delay(250);
  }
  throw new Error(
    `Timed out waiting for replacement app-server-dev worker: ${JSON.stringify({ previousPID, lastMatches })}`
  );
}

async function verifyWorkerCrashRecovery(baseURL, tempRoot) {
  const before = await assertQuiescentFingerprintHeaders(baseURL);
  const worker = await activeWorkerProcess(tempRoot);
  process.kill(worker.pid, "SIGKILL");
  const replacement = await waitForReplacementWorker(tempRoot, worker.pid);
  const after = await waitForDevStatus(
    baseURL,
    "worker crash recovery",
    (status) => isQuiescentDevStatus(status)
      && status.sourceFingerprint === before.status.sourceFingerprint,
    hmrTimeoutMs
  );
  const headers = await assertQuiescentFingerprintHeaders(baseURL);
  if (headers.headers.build !== before.headers.build) {
    throw new Error(`Worker crash recovery rebuilt the executable: ${JSON.stringify({ before, after, headers })}`);
  }
  report.workerCrashRecovery = {
    killedPID: worker.pid,
    replacementPID: replacement.pid,
    command: replacement.command,
    fingerprint: after.sourceFingerprint,
  };
  recordPhase("reconciler.worker-crash.recovered");
}

async function prepareAppCopy(root) {
  const appRoot = path.join(root, "CounterApp");
  await rm(appRoot, { recursive: true, force: true });
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
    new RegExp(
      `\\.package\\(url:\\s*"https:\\/\\/github\\.com\\/1amageek\\/swift-web\\.git",\\s*from:\\s*"${expectedSwiftWebVersion.replaceAll(".", "\\.")}"\\),`
    ),
    `.package(path: "${swiftStringLiteral(swiftWebRoot)}"),`
  );
  const expectedSwiftHTMLDependency = `.package(url: "https://github.com/1amageek/swift-html.git", from: "${expectedSwiftHTMLVersion}")`;
  if (!manifest.includes(swiftStringLiteral(swiftWebRoot)) || !manifest.includes(expectedSwiftHTMLDependency)) {
    throw new Error("Failed to use local swift-web with the released swift-html dependency.");
  }
  await writeFile(packageFile, manifest);

  await writeFile(
    path.join(appRoot, "Sources", "CounterApp", "ClientDeferredCounter.swift"),
    `import SwiftHTML
import SwiftWebUI

public struct CounterValue: Component {
    let label: String
    let value: Int

    public init(label: String, value: Int) {
        self.label = label
        self.value = value
    }

    public var content: some Component {
        VStack(spacing: .xsmall) {
            Text(label).as(.small).foregroundStyle(.secondary)
            Text(String(value)).as(.strong)
                .font(.largeTitle)
                .foregroundStyle(.accent)
                .accessibilityIdentifier("counter-value")
                .accessibilityValue(String(value))
        }
    }
}

public struct ClientDeferredCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .interaction
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .large) {
                Text("Deferred Client Counter").as(.h3)
                Text(
                    "This counter hydrates only after user interaction."
                )
                .foregroundStyle(.secondary)
                CounterValue(label: "Deferred value", value: value)
                Button("Increment deferred") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("deferred-counter")
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

    public var content: some Component {
        GroupBox {
            VStack(spacing: .large) {
                Text("Visible Client Counter").as(.h3)
                Text("This counter hydrates when it enters the viewport.").foregroundStyle(.secondary)
                CounterValue(label: "Visible value", value: value)
                Button("Increment visible") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("visible-counter")
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct ClientIdleCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .idle
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .large) {
                Text("Idle Client Counter").as(.h3)
                Text("This counter hydrates during the browser idle stage.").foregroundStyle(.secondary)
                CounterValue(label: "Idle value", value: value)
                Button("Increment idle") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("idle-counter")
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct ClientManualCounter: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .large) {
                Text("Manual Client Counter").as(.h3)
                Text("This counter hydrates only when the runtime explicitly loads its bundle.").foregroundStyle(.secondary)
                CounterValue(label: "Manual value", value: value)
                Button("Increment manual") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("manual-counter")
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public struct ClientSharedBadgeA: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .shared("badges")
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .small) {
                Text("Shared Badge A").as(.h3)
                CounterValue(label: "Badge A", value: value)
                Button("Increment shared A") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("shared-badge-a")
    }
}

public struct ClientSharedBadgeB: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .shared("badges")
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .small) {
                Text("Shared Badge B").as(.h3)
                CounterValue(label: "Badge B", value: value)
                Button("Increment shared B") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("shared-badge-b")
    }
}

public struct ClientNamedToolA: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .named("tools")
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .small) {
                Text("Named Tool A").as(.h3)
                CounterValue(label: "Tool A", value: value)
                Button("Increment named A") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("named-tool-a")
    }
}

public struct ClientNamedToolB: ClientComponent, Sendable {
    public static let loadPolicy: LoadPolicy = .manual
    public static let bundle: BundlePolicy = .named("tools")
    @State private var value = 0

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .small) {
                Text("Named Tool B").as(.h3)
                CounterValue(label: "Tool B", value: value)
                Button("Increment named B") {
                    value += 1
                }
            }
        }
        .accessibilityIdentifier("named-tool-b")
    }
}
`
  );

  await writeFile(
    path.join(appRoot, "Sources", "CounterApp", "ClientEnvironmentBadge.swift"),
    `import SwiftHTML
import SwiftWebUI

public struct SceneGreetingKey: ClientEnvironmentKey {
    public static let defaultValue = "default-greeting"
}

extension EnvironmentValues {
    public var sceneGreeting: String {
        get { self[SceneGreetingKey.self] }
        set { self[SceneGreetingKey.self] = newValue }
    }
}

public struct ClientEnvironmentBadge: ClientComponent, Sendable {
    @Environment(\\.sceneGreeting) private var greeting
    @State private var revealed = false

    public init() {}

    public var content: some Component {
        // Read during SSR as well, so the value enters the hydration snapshot.
        let greeting = self.greeting
        return GroupBox {
            VStack(spacing: .small) {
                Text("Scene Environment Badge").as(.h3)
                Text(revealed ? greeting : "waiting").as(.strong)
                    .accessibilityIdentifier("env-greeting")
                Button("Reveal environment") {
                    revealed = true
                }
            }
        }
        .accessibilityIdentifier("environment-badge")
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
`
  );

  const appFile = path.join(appRoot, "Sources", "CounterApp", "App.swift");
  const appSource = await readFile(appFile, "utf8");
  const updatedAppSource = appSource.replace(
    /ActorScene\(counterService\) \{\n(\s*)CounterPage\(counterService: counterService\)\n(\s*)\}/,
    'ActorScene(counterService) {\n$1CounterPage(counterService: counterService)\n$2}\n$2.environment(\\.sceneGreeting, "scene-injected")'
  );
  if (updatedAppSource === appSource) {
    throw new Error("Failed to attach .environment to the CounterApp scene.");
  }
  await writeFile(appFile, updatedAppSource);

  await writeFile(
    path.join(appRoot, "Sources", "CounterApp", "CounterPageE2EComponents.swift"),
    `import Foundation
import SwiftHTML
import SwiftWebUI

struct CounterPageE2EComponents: Component {
    var content: some Component {
        ClientEnvironmentBadge()

        GroupBox {
            VStack(spacing: .small) {
                Text("Loading Policy E2E Spacer").as(.h3)
                Text("The visible counter sits below this spacer so IntersectionObserver is required.")
            }
        }
        .accessibilityIdentifier("visible-policy-spacer")
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
    }
}
`
  );

  const counterPageFile = path.join(appRoot, "Sources", "CounterApp", "Routes", "CounterPage.swift");
  const counterPage = await readFile(counterPageFile, "utf8");
  let updatedCounterPage = counterPage.replace(
    /ClientCounter\(\)\n\n(\s*)GroupBox \{/,
    "ClientCounter()\n$1ClientDeferredCounter()\n\n$1GroupBox {"
  );
  const insertedDeferredCounter = updatedCounterPage !== counterPage;
  updatedCounterPage = updatedCounterPage.replace(
    "            Link(\"Reload page\", destination: URL(string: \"/counter\")!)",
    `            CounterPageE2EComponents()

            Link("Reload page", destination: URL(string: "/counter")!)`
  );
  const insertedLoadingPolicyCounters = updatedCounterPage.includes("CounterPageE2EComponents()");
  if (!insertedDeferredCounter || !insertedLoadingPolicyCounters) {
    throw new Error("Failed to inject E2E ClientComponents into CounterPage.swift.");
  }
  await writeFile(counterPageFile, updatedCounterPage);
  return appRoot;
}

async function launchDevServer(appRoot, scratchRoot, port, host) {
  const swiftWebExecutable = await resolveSwiftWebExecutable();
  const wasmSwiftSDK = process.env.SWIFT_WEB_WASM_SDK || "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a_wasm";
  const hostSwiftExecutable = process.env.SWIFT_WEB_HOST_SWIFT
    || process.env.SWIFTWEB_E2E_HOST_SWIFT_EXECUTABLE
    || process.env.SWIFTWEB_E2E_SWIFT_EXECUTABLE;
  const hostSwiftToolchainBin = process.env.SWIFT_WEB_HOST_TOOLCHAIN_BIN
    || (hostSwiftExecutable ? path.dirname(hostSwiftExecutable) : undefined);
  const childEnvironment = {
    ...process.env,
    SWIFT_WEB_PACKAGE_PATH: swiftWebRoot,
    SWIFT_WEB_WASM_SDK: wasmSwiftSDK,
  };
  if (hostSwiftExecutable) {
    childEnvironment.SWIFT_WEB_HOST_SWIFT = hostSwiftExecutable;
    report.hostSwiftExecutable = hostSwiftExecutable;
  }
  if (hostSwiftToolchainBin) {
    childEnvironment.SWIFT_WEB_HOST_TOOLCHAIN_BIN = hostSwiftToolchainBin;
    report.hostSwiftToolchainBin = hostSwiftToolchainBin;
  }
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
      "--host",
      host,
      "--port",
      String(port),
    ],
    {
      cwd: swiftWebRoot,
      env: childEnvironment,
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
      console.log(`[sweb dev] ${line}`);
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
    await expectCounterValue(page, componentSelector("client-counter"), 0);
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
    if (response.status() >= 400 && response.url() !== report.expectedExpiredGenerationURL) {
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
        location: message.location(),
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
  return text === "Failed to load resource: the server responded with a status of 404 (Not Found)"
    || (Boolean(report.expectedExpiredGenerationURL)
      && text === "Failed to load resource: the server responded with a status of 410 (Gone)");
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

function componentSelector(identifier) {
  return `[data-accessibility-identifier="${identifier}"]`;
}

async function counterValue(page, selector) {
  const text = await page
    .locator(`${selector} ${componentSelector("counter-value")}`)
    .first()
    .innerText();
  return Number(text.trim());
}

async function expectCounterValue(page, selector, expected, timeout = timeoutMs) {
  await page.waitForFunction(
    ({ selector, expected }) => {
      const value = document.querySelector(`${selector} [data-accessibility-identifier="counter-value"]`);
      return value && value.textContent.trim() === String(expected);
    },
    { selector, expected },
    { timeout }
  );
}

async function waitForServerReconciliation(page, previousEventID) {
  await page.waitForFunction(
    (previousID) => {
      const event = globalThis.__swiftWebDevReload?.lastAppliedEvent;
      return ["serverRestarted", "pagePatch"].includes(event?.kind)
        && event.id !== previousID;
    },
    previousEventID,
    { timeout: hmrTimeoutMs }
  );
  return await page.evaluate(() => globalThis.__swiftWebDevReload?.lastAppliedEvent?.id ?? null);
}

async function browserRuntimeState(page) {
  return await page.evaluate(() => ({
    devReload: {
      exists: !!globalThis.__swiftWebDevReload,
      eventSourceReadyState: globalThis.__swiftWebDevReload?.eventSource?.readyState ?? null,
      connectedAt: globalThis.__swiftWebDevReload?.connectedAt ?? null,
      lastEventKind: globalThis.__swiftWebDevReload?.lastEvent?.kind ?? null,
      lastAppliedEventKind: globalThis.__swiftWebDevReload?.lastAppliedEvent?.kind ?? null,
      lastErrorEventKind: globalThis.__swiftWebDevReload?.lastErrorEvent?.kind ?? null,
      lastErrorEventMessage: globalThis.__swiftWebDevReload?.lastErrorEvent?.message ?? null,
      lastServerRebuildErrorEventKind: globalThis.__swiftWebDevReload?.lastServerRebuildErrorEvent?.kind ?? null,
      lastServerRebuildErrorEventMessage: globalThis.__swiftWebDevReload?.lastServerRebuildErrorEvent?.message ?? null,
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

    recordPhase("environment.badge");
    {
      const badge = '[data-accessibility-identifier="environment-badge"]';
      const before = await page
        .locator(`${badge} [data-accessibility-identifier="env-greeting"]`)
        .first()
        .innerText();
      if (before.trim() !== "waiting") {
        throw new Error(`environment badge should render "waiting" before reveal, got: ${before}`);
      }
      await page.locator(`${badge} button`).first().click();
      await page.waitForFunction(
        () => {
          const el = document.querySelector('[data-accessibility-identifier="env-greeting"]');
          return el && el.textContent.trim() === "scene-injected";
        },
        undefined,
        { timeout: timeoutMs }
      );
    }
    recordPhase("environment.badge.ok");

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

    await expectCounterValue(page, componentSelector("client-counter"), 0);
    await expectCounterValue(page, componentSelector("server-counter"), 0);
    await expectCounterValue(page, componentSelector("deferred-counter"), 0);
    await expectCounterValue(page, componentSelector("visible-counter"), 0);
    await expectCounterValue(page, componentSelector("idle-counter"), 0);
    await expectCounterValue(page, componentSelector("manual-counter"), 0);
    await expectCounterValue(page, componentSelector("shared-badge-a"), 0);
    await expectCounterValue(page, componentSelector("shared-badge-b"), 0);
    await expectCounterValue(page, componentSelector("named-tool-a"), 0);
    await expectCounterValue(page, componentSelector("named-tool-b"), 0);

    recordPhase("idle.auto-load");
    await page.waitForFunction(
      (bundleID) => (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(bundleID),
      idleComponent.bundleID,
      { timeout: timeoutMs }
    );

    recordPhase("visible.viewport-load");
    const visibleBoundary = page.locator(`[data-component="${visibleComponent.componentID}"]`);
    const visibleBeforeScroll = await visibleBoundary.evaluate((element) => {
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
    await visibleBoundary.scrollIntoViewIfNeeded();
    await page.waitForFunction(
      (bundleID) => (window.__swiftWebWasmRuntimeStatus?.loadedBundleIDs || []).includes(bundleID),
      visibleComponent.bundleID,
      { timeout: timeoutMs }
    );
    await page.locator(componentSelector("visible-counter")).getByRole("button", { name: "Increment visible" }).click();
    await expectCounterValue(page, componentSelector("visible-counter"), 1);
    await page.locator(componentSelector("idle-counter")).getByRole("button", { name: "Increment idle" }).click();
    await expectCounterValue(page, componentSelector("idle-counter"), 1);

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
    await page.locator(componentSelector("manual-counter")).getByRole("button", { name: "Increment manual" }).click();
    await page.locator(componentSelector("shared-badge-b")).getByRole("button", { name: "Increment shared B" }).click();
    await page.locator(componentSelector("named-tool-a")).getByRole("button", { name: "Increment named A" }).click();
    await expectCounterValue(page, componentSelector("manual-counter"), 1);
    await expectCounterValue(page, componentSelector("shared-badge-b"), 1);
    await expectCounterValue(page, componentSelector("named-tool-a"), 1);
    report.loadingPolicyAfterExplicitLoad = await runtimeManifestSnapshot(page);

    recordPhase("deferred.interaction-load");
    const deferredBoundary = page.locator(`[data-component="${deferredComponent.componentID}"]`);
    await deferredBoundary.hover();
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
    await page.locator(componentSelector("deferred-counter")).getByRole("button", { name: "Increment deferred" }).click();
    await expectCounterValue(page, componentSelector("deferred-counter"), 1);

    recordPhase("client.increment");
    await page.locator(componentSelector("client-counter")).getByRole("button", { name: "Increment" }).click();
    await expectCounterValue(page, componentSelector("client-counter"), 1);
    const markerAfterClient = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterClient !== initialMarker) {
      throw new Error("Client WASM event caused a full page reload.");
    }
    const clientDispatchCount = await page.evaluate(() => window.__swiftWebWasmRuntimeMetrics.summary.eventDispatchCount || 0);
    if (clientDispatchCount < 1) {
      throw new Error("Client WASM event dispatch metrics were not recorded.");
    }

    recordPhase("server.increment.invalidate");
    await page.locator(componentSelector("server-counter")).getByRole("button", { name: "Increment" }).click();
    await expectCounterValue(page, componentSelector("server-counter"), 1);
    await expectCounterValue(page, componentSelector("client-counter"), 1);
    const markerAfterServer = await page.evaluate(() => window.__swiftWebE2EMarker);
    if (markerAfterServer !== initialMarker) {
      throw new Error("ServerAction invalidate caused a full page reload.");
    }

    report.devReloadBeforeHMR = await browserRuntimeState(page);

    recordPhase("client.hmr.source-change");
    const clientCounterFile = path.join(appRoot, "Sources", "CounterApp", "ClientCounter.swift");
    const originalSource = await readFile(clientCounterFile, "utf8");
    let updatedSource = originalSource.replace("Text(\"Client Counter\").as(.h2)", "Text(\"Client Counter HMR\").as(.h2)");
    if (updatedSource === originalSource) {
      updatedSource = originalSource.replace("Heading(\"Client Counter\")", "Heading(\"Client Counter HMR\")");
    }
    if (updatedSource === originalSource) {
      throw new Error("HMR source marker was not found in ClientCounter.swift.");
    }
    const previousHMRServerEventID = await page.evaluate(() => {
      const event = globalThis.__swiftWebDevReload?.lastAppliedEvent;
      return ["serverRestarted", "pagePatch"].includes(event?.kind) ? event.id : null;
    });
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
    await waitForServerReconciliation(page, previousHMRServerEventID);
    await expectCounterValue(page, componentSelector("client-counter"), 1);
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
    report.hmrFailureStatus = await waitForDevStatus(
      baseURL,
      "latched build failure",
      (status) => status.phase === "error"
        && status.stale === true
        && Boolean(status.lastErrorSummary)
    );
    const failedWorkerResponse = await fetch(`${baseURL}/counter`, {
      headers: { Accept: "text/html" },
    });
    const failedWorkerBody = await failedWorkerResponse.text();
    if (!failedWorkerResponse.ok || !failedWorkerBody.includes("Client Counter HMR")) {
      throw new Error("The previous worker did not remain available after a failed rebuild.");
    }
    const failureLogCount = report.serverLogTail.filter(
      (line) => /Build failed|build failed:/.test(line)
    ).length;
    await delay(3_500);
    const heldFailureStatus = await fetchDevStatus(baseURL);
    const heldFailureLogCount = report.serverLogTail.filter(
      (line) => /Build failed|build failed:/.test(line)
    ).length;
    if (heldFailureStatus.sourceFingerprint !== report.hmrFailureStatus.sourceFingerprint
      || heldFailureStatus.phase !== "error"
      || heldFailureLogCount !== failureLogCount) {
      throw new Error(
        `Failed source fingerprint did not remain latched: ${JSON.stringify({ heldFailureStatus, failureLogCount, heldFailureLogCount })}`
      );
    }
    report.hmrFailureHold = {
      status: heldFailureStatus,
      failureLogCount,
      previousWorkerServedHTML: true,
    };

    recordPhase("client.hmr.recover");
    await writeFile(clientCounterFile, updatedSource);
    report.hmrRecoveryStatus = await waitForDevStatus(
      baseURL,
      "build failure recovery",
      isQuiescentDevStatus
    );
    report.hmrRecoveryHeaders = await assertQuiescentFingerprintHeaders(baseURL);
    await page.waitForFunction(
      () => {
        const applied = globalThis.__swiftWebDevReload?.lastAppliedEvent;
        return applied?.kind === "connected"
          && applied?.message === "SwiftWeb source failure cleared"
          && globalThis.__swiftWebDevReload?.lastErrorEvent?.kind === "error"
          && document.body?.textContent.includes("Client Counter HMR");
      },
      undefined,
      { timeout: hmrTimeoutMs }
    );
    report.hmrRecovery = {
      runtime: await browserRuntimeState(page),
      marker: await page.evaluate(() => window.__swiftWebE2EMarker),
      clientCounter: await counterValue(page, componentSelector("client-counter")),
      serverCounter: await counterValue(page, componentSelector("server-counter")),
    };
    if (report.hmrRecovery.runtime.devReload.lastErrorEventKind !== "error") {
      throw new Error(`Failed ClientComponent HMR did not report an error event: ${JSON.stringify(report.hmrRecovery)}`);
    }
    if (report.hmrRecovery.marker !== initialMarker) {
      throw new Error("Failed ClientComponent HMR caused a full page reload.");
    }
    await expectCounterValue(page, componentSelector("client-counter"), 1, 30_000);
    await expectCounterValue(page, componentSelector("server-counter"), 0, 30_000);
    await expectCounterValue(page, componentSelector("deferred-counter"), 1, 30_000);
    await expectCounterValue(page, componentSelector("visible-counter"), 1, 30_000);
    await expectCounterValue(page, componentSelector("idle-counter"), 1, 30_000);
    await expectCounterValue(page, componentSelector("manual-counter"), 1, 30_000);
    await expectCounterValue(page, componentSelector("shared-badge-b"), 1, 30_000);
    await expectCounterValue(page, componentSelector("named-tool-a"), 1, 30_000);

    recordPhase("client.hmr.transaction-rollback");
    report.hmrDOMTransaction = await page.evaluate(async () => {
      const runtime = window.__swiftWebWasmRuntime;
      const target = document.querySelector("[data-node]");
      if (!runtime || !target) {
        throw new Error("WASM runtime or hydration target was unavailable");
      }
      const nodeID = Number(target.getAttribute("data-node"));
      const targetBefore = target.outerHTML;
      const styleBefore = document.getElementById("swui-atomic")?.textContent ?? null;
      const originalStageHotUpdate = runtime.stageHotUpdate;
      const order = [];
      let stageIndex = 0;
      runtime.eventQueue = runtime.eventQueue.then(async () => {
        await new Promise((resolve) => setTimeout(resolve, 20));
        order.push("event");
      });
      runtime.stageHotUpdate = async (update) => {
        order.push(`hmr-${stageIndex}`);
        const response = stageIndex === 0
          ? {
              atomicStyleRules: [{ className: "swiftweb-hmr-rollback", body: "color: red" }],
              commandBatch: {
                commands: [{
                  setProperty: {
                    node: { rawValue: nodeID },
                    name: "data-hmr-rollback",
                    value: "mutated"
                  }
                }]
              },
              appliesDOMCommandsInRuntime: false
            }
          : {
              atomicStyleRules: [],
              commandBatch: {
                commands: [{
                  updateText: {
                    node: { rawValue: 2_147_483_647 },
                    value: "must-not-commit"
                  }
                }]
              },
              appliesDOMCommandsInRuntime: false
            };
        stageIndex += 1;
        return { bundleID: update.bundleID, update, response };
      };
      let error = null;
      try {
        await runtime.applyHotUpdateBatch([
          { bundleID: "hmr-transaction-a", assetPath: "/noop-a.wasm", contentHash: crypto.randomUUID() },
          { bundleID: "hmr-transaction-b", assetPath: "/noop-b.wasm", contentHash: crypto.randomUUID() }
        ]);
      } catch (caught) {
        error = String(caught && caught.message ? caught.message : caught);
      } finally {
        runtime.stageHotUpdate = originalStageHotUpdate;
      }
      const restoredTarget = document.querySelector(`[data-node="${nodeID}"]`);
      const styleAfter = document.getElementById("swui-atomic")?.textContent ?? null;
      return {
        error,
        order,
        targetRestored: restoredTarget?.outerHTML === targetBefore,
        styleRestored: styleAfter === styleBefore,
        leakedAttribute: restoredTarget?.getAttribute("data-hmr-rollback") ?? null
      };
    });
    if (!report.hmrDOMTransaction.error?.includes("could not be applied")
      || report.hmrDOMTransaction.order.join(",") !== "event,hmr-0,hmr-1"
      || !report.hmrDOMTransaction.targetRestored
      || !report.hmrDOMTransaction.styleRestored
      || report.hmrDOMTransaction.leakedAttribute !== null) {
      throw new Error(
        `Client HMR DOM transaction did not roll back atomically: ${JSON.stringify(report.hmrDOMTransaction)}`
      );
    }

    report.hmrRuntimeOwnership = await page.evaluate(async () => {
      const runtime = window.__swiftWebWasmRuntime;
      const savedState = runtime.captureHotUpdateState();
      const originalShutdownRuntime = runtime.shutdownRuntime;
      const shutdowns = [];
      const oldInstance = { name: "old-shared-runtime" };
      const oldSwiftRuntime = { name: "old-shared-owner" };
      const newInstance = { name: "new-runtime" };
      const newSwiftRuntime = { name: "new-owner" };
      const failingInstance = { name: "failing-runtime" };
      const succeedingInstance = { name: "succeeding-runtime" };
      const provisionalInstance = { name: "provisional-runtime" };
      const failedCleanupInstance = { name: "provisional-cleanup-failure" };
      let cleanupError = null;
      let cleanupRequiresFullReload = false;
      let provisionalStartError = null;
      let provisionalCleanupError = null;
      let provisionalCleanupRequiresFullReload = false;
      let preservedStartError = null;
      try {
        runtime.registerRuntimeAlias("ownership-a", oldInstance, oldSwiftRuntime);
        runtime.registerRuntimeAlias("ownership-b", oldInstance, oldSwiftRuntime);
        runtime.loadedBundleIDs.add("ownership-a");
        runtime.loadedBundleIDs.add("ownership-b");
        const transactionState = runtime.captureHotUpdateState();

        const partialRetirement = runtime.releaseRuntimeAlias("ownership-a");
        const sharedAliasRemained = runtime.instances.get("ownership-b") === oldInstance;
        runtime.registerRuntimeAlias("ownership-a", newInstance, newSwiftRuntime);
        const newRuntimeRecord = runtime.releaseRuntimeAlias("ownership-a");
        runtime.shutdownRuntime = async (instance) => {
          shutdowns.push(instance.name);
        };
        await runtime.shutdownRuntimeRecords([newRuntimeRecord]);
        runtime.restoreHotUpdateState(transactionState);
        const rollbackRestored = runtime.instances.get("ownership-a") === oldInstance
          && runtime.instances.get("ownership-b") === oldInstance
          && runtime.runtimeRecords.get(oldInstance)?.aliases.size === 2;

        const firstAliasRetirement = runtime.releaseRuntimeAlias("ownership-a");
        const lastAliasRetirement = runtime.releaseRuntimeAlias("ownership-b");
        await runtime.shutdownRuntimeRecords([
          firstAliasRetirement,
          lastAliasRetirement,
          lastAliasRetirement
        ]);

        runtime.shutdownRuntime = async (instance) => {
          shutdowns.push(instance.name);
        };
        try {
          await runtime.startOwnedRuntime(
            provisionalInstance,
            { name: "provisional-owner" },
            async () => {
              throw new Error("expected provisional start failure");
            }
          );
        } catch (error) {
          provisionalStartError = String(error && error.message ? error.message : error);
        }

        runtime.shutdownRuntime = async (instance) => {
          shutdowns.push(instance.name);
          throw new Error("expected provisional cleanup failure");
        };
        try {
          await runtime.startOwnedRuntime(
            failedCleanupInstance,
            { name: "provisional-failed-cleanup-owner" },
            async () => {
              throw new Error("preserved provisional start failure");
            }
          );
        } catch (error) {
          provisionalCleanupError = String(error && error.message ? error.message : error);
          provisionalCleanupRequiresFullReload = error?.swiftWebRequiresFullReload === true;
          preservedStartError = String(
            error?.swiftWebInstantiationError?.message || error?.swiftWebInstantiationError || ""
          );
        }

        runtime.registerRuntimeAlias("ownership-failing", failingInstance, { name: "failing-owner" });
        runtime.registerRuntimeAlias(
          "ownership-succeeding",
          succeedingInstance,
          { name: "succeeding-owner" }
        );
        const failingRecord = runtime.releaseRuntimeAlias("ownership-failing");
        const succeedingRecord = runtime.releaseRuntimeAlias("ownership-succeeding");
        runtime.shutdownRuntime = async (instance) => {
          shutdowns.push(instance.name);
          if (instance === failingInstance) {
            throw new Error("expected cleanup failure");
          }
        };
        try {
          await runtime.shutdownRuntimeRecords([failingRecord, succeedingRecord]);
        } catch (error) {
          cleanupError = String(error && error.message ? error.message : error);
          cleanupRequiresFullReload = error?.swiftWebRequiresFullReload === true;
        }

        return {
          partialRetirementWasDeferred: partialRetirement === null,
          sharedAliasRemained,
          rollbackRestored,
          oldRuntimeShutdownCount: shutdowns.filter(
            (name) => name === "old-shared-runtime"
          ).length,
          newRuntimeShutdownCount: shutdowns.filter(
            (name) => name === "new-runtime"
          ).length,
          provisionalRuntimeShutdownCount: shutdowns.filter(
            (name) => name === "provisional-runtime"
          ).length,
          provisionalRecordReleased: !runtime.runtimeRecords.has(provisionalInstance)
            && !runtime.runtimeRecords.has(failedCleanupInstance),
          provisionalStartError,
          provisionalCleanupError,
          provisionalCleanupRequiresFullReload,
          preservedStartError,
          cleanupAttemptedAll: shutdowns.includes("failing-runtime")
            && shutdowns.includes("succeeding-runtime"),
          cleanupError,
          cleanupRequiresFullReload
        };
      } finally {
        runtime.shutdownRuntime = originalShutdownRuntime;
        runtime.restoreHotUpdateState(savedState);
      }
    });
    if (!report.hmrRuntimeOwnership.partialRetirementWasDeferred
      || !report.hmrRuntimeOwnership.sharedAliasRemained
      || !report.hmrRuntimeOwnership.rollbackRestored
      || report.hmrRuntimeOwnership.oldRuntimeShutdownCount !== 1
      || report.hmrRuntimeOwnership.newRuntimeShutdownCount !== 1
      || report.hmrRuntimeOwnership.provisionalRuntimeShutdownCount !== 1
      || !report.hmrRuntimeOwnership.provisionalRecordReleased
      || report.hmrRuntimeOwnership.provisionalStartError !== "expected provisional start failure"
      || report.hmrRuntimeOwnership.provisionalCleanupError !== "expected provisional cleanup failure"
      || !report.hmrRuntimeOwnership.provisionalCleanupRequiresFullReload
      || report.hmrRuntimeOwnership.preservedStartError !== "preserved provisional start failure"
      || !report.hmrRuntimeOwnership.cleanupAttemptedAll
      || report.hmrRuntimeOwnership.cleanupError !== "expected cleanup failure"
      || !report.hmrRuntimeOwnership.cleanupRequiresFullReload) {
      throw new Error(
        `Client HMR runtime ownership was not physical-instance safe: ${JSON.stringify(report.hmrRuntimeOwnership)}`
      );
    }

    recordPhase("server.hmr.page-change");
    const counterPageFile = path.join(appRoot, "Sources", "CounterApp", "Routes", "CounterPage.swift");
    const originalPageSource = await readFile(counterPageFile, "utf8");
    const updatedPageSource = originalPageSource.replace(
      "Each button posts a delta to the SwiftWeb host. The value is read from server state on the next render.",
      "Server worker restart HMR applied. The value is read from the new SwiftWeb worker."
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
    await expectCounterValue(page, componentSelector("client-counter"), 1);
    await expectCounterValue(page, componentSelector("deferred-counter"), 1);
    await expectCounterValue(page, componentSelector("visible-counter"), 1);
    await expectCounterValue(page, componentSelector("idle-counter"), 1);
    await expectCounterValue(page, componentSelector("manual-counter"), 1);
    await expectCounterValue(page, componentSelector("shared-badge-b"), 1);
    await expectCounterValue(page, componentSelector("named-tool-a"), 1);
    await expectCounterValue(page, componentSelector("server-counter"), 0);

    const finalValues = {
      client: await counterValue(page, componentSelector("client-counter")),
      server: await counterValue(page, componentSelector("server-counter")),
      deferred: await counterValue(page, componentSelector("deferred-counter")),
      visible: await counterValue(page, componentSelector("visible-counter")),
      idle: await counterValue(page, componentSelector("idle-counter")),
      manual: await counterValue(page, componentSelector("manual-counter")),
      sharedB: await counterValue(page, componentSelector("shared-badge-b")),
      namedA: await counterValue(page, componentSelector("named-tool-a")),
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

    recordPhase("client.hmr.expired-generation-reload");
    let expiredGenerationResponses = 0;
    await page.route("**/__swiftweb/dev/wasm/**", async (route) => {
      if (expiredGenerationResponses === 0) {
        expiredGenerationResponses += 1;
        report.expectedExpiredGenerationURL = route.request().url();
        await route.fulfill({
          status: 410,
          contentType: "text/plain; charset=utf-8",
          body: "expired SwiftWeb WASM generation",
        });
        return;
      }
      await route.continue();
    });
    const expiredReloadSource = updatedSource.replace(
      "Client Counter HMR",
      "Client Counter Expired Reload"
    );
    if (expiredReloadSource === updatedSource) {
      throw new Error("Expired-generation HMR source marker was not found.");
    }
    await writeFile(clientCounterFile, expiredReloadSource);
    await page.waitForFunction(
      () => globalThis.__swiftWebE2EMarker === undefined,
      undefined,
      { timeout: hmrTimeoutMs }
    );
    await page.waitForFunction(
      () => document.documentElement.getAttribute("data-wasm-ready") === "true"
        && document.body?.textContent?.includes("Client Counter Expired Reload"),
      undefined,
      { timeout: hmrTimeoutMs }
    );
    await page.unroute("**/__swiftweb/dev/wasm/**");
    if (expiredGenerationResponses !== 1) {
      throw new Error(
        `Expected one expired generation response before reload, got ${expiredGenerationResponses}`
      );
    }
    report.expiredGenerationReload = {
      expiredGenerationResponses,
      runtime: await browserRuntimeState(page),
    };
  } finally {
    await browser.close();
  }
}

let tempRoot;
let devServer;
const reusableTempRoot = process.env.SWIFTWEB_E2E_REUSE_TEMP_ROOT
  ? path.resolve(process.env.SWIFTWEB_E2E_REUSE_TEMP_ROOT)
  : null;

try {
  const tempParent = path.join(swiftWebRoot, ".swiftweb", "browser-e2e");
  await mkdir(tempParent, { recursive: true });
  if (reusableTempRoot) {
    tempRoot = reusableTempRoot;
    await mkdir(tempRoot, { recursive: true });
    report.reusedTempRoot = true;
  } else {
    tempRoot = await mkdtemp(path.join(tempParent, "counter-"));
  }
  const appRoot = await prepareAppCopy(tempRoot);
  const scratchRoot = path.join(tempRoot, "scratch");
  await mkdir(scratchRoot, { recursive: true });
  const port = await availablePort();
  const baseURL = `http://127.0.0.1:${port}`;
  report.tempRoot = tempRoot;
  report.appRoot = appRoot;
  report.baseURL = baseURL;
  report.bindHost = bindHost;

  recordPhase("server.start", { baseURL, bindHost });
  devServer = await launchDevServer(appRoot, scratchRoot, port, bindHost);
  await verifyInitialBuildEdit(baseURL, appRoot);
  await waitForHTTP(`${baseURL}/counter`, Date.now() + timeoutMs);
  await waitForDevStatus(
    baseURL,
    "initial-build edit convergence",
    isQuiescentDevStatus,
    hmrTimeoutMs
  );
  const initialConvergence = await assertQuiescentFingerprintHeaders(baseURL);
  if (!initialConvergence.body.includes("Server Counter Initial Build Edit")) {
    throw new Error("An edit made during the initial build was not served by the converged worker.");
  }
  report.initialConvergence = {
    status: initialConvergence.status,
    headers: initialConvergence.headers,
    initialBuildEditServed: true,
  };
  await verifyTouchDoesNotRebuild(baseURL, appRoot, tempRoot);
  await verifyWorkerCrashRecovery(baseURL, tempRoot);
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
  if (tempRoot && !reusableTempRoot && process.env.SWIFTWEB_E2E_KEEP_TEMP !== "1") {
    await removeTemporaryRoot(tempRoot);
  }
  const output = JSON.stringify(report, null, 2);
  console.log(output);
}
