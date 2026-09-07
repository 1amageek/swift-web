import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { promisify } from "node:util";
import { runInNewContext } from "node:vm";

const execute = promisify(execFile);
const runner = fileURLToPath(new URL("./counter-wasm-runtime-e2e.mjs", import.meta.url));

for (const reuse of [false, true]) {
  test(`app preparation resets authored input and ${reuse ? "retains" : "removes"} build state`, async () => {
    const root = await mkdtemp(path.join(os.tmpdir(), "swiftweb-counter-prepare-"));
    const appRoot = path.join(root, "CounterApp");
    const swiftWebRoot = path.resolve(path.dirname(runner), "../..");
    try {
      for (const name of [".build", ".swiftweb", "Sources"]) {
        await mkdir(path.join(appRoot, name), { recursive: true });
        await writeFile(path.join(appRoot, name, "stale"), name);
      }
      await writeFile(path.join(appRoot, "Package.resolved"), "retained resolution");
      await writeFile(path.join(appRoot, "Package.swift"), "stale manifest");
      const source = await readFile(runner, "utf8");
      const declaration = source.slice(source.indexOf("async function prepareAppCopy("), source.indexOf("async function launchDevServer("));
      const prepare = runInNewContext(`(${declaration})`, {
        path, cp, mkdir, readFile, readdir, rm, writeFile, existsSync,
        swiftWebRoot, expectedSwiftHTMLVersion: "0.16.1",
        exampleAppRoot: path.join(swiftWebRoot, "Examples", "CounterApp"),
        reusableTempRoot: reuse ? root : null,
        swiftStringLiteral: (value) => value.replaceAll("\\", "\\\\").replaceAll('"', '\\"'),
      });
      assert.equal(await prepare(root), appRoot);
      for (const name of [".build", ".swiftweb"]) {
        assert.equal(existsSync(path.join(appRoot, name, "stale")), reuse);
      }
      assert.equal(existsSync(path.join(appRoot, "Sources", "stale")), false);
      assert.match(await readFile(path.join(appRoot, "Package.swift"), "utf8"), /\.package\(path:/);
      if (reuse) assert.equal(await readFile(path.join(appRoot, "Package.resolved"), "utf8"), "retained resolution");
      else if (existsSync(path.join(appRoot, "Package.resolved"))) assert.notEqual(await readFile(path.join(appRoot, "Package.resolved"), "utf8"), "retained resolution");
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
}

for (const enabled of [false, true]) {
  test(enabled ? "missing WebKit fails before app preparation or build" : "required invocation rejects disabled opt-in", async () => {
    const root = await mkdtemp(path.join(os.tmpdir(), "swiftweb-webkit-preflight-"));
    const appRoot = path.join(root, "unprepared-app");
    try {
      await assert.rejects(execute(process.execPath, [runner], {
        env: {
          ...process.env,
          SWIFTWEB_BROWSER_E2E: enabled ? "1" : "0",
          SWIFTWEB_E2E_REQUIRE_WEBKIT: enabled ? "0" : "1",
          SWIFTWEB_E2E_REUSE_TEMP_ROOT: appRoot,
          PLAYWRIGHT_BROWSERS_PATH: root,
        },
        timeout: 30_000,
      }), (error) => {
        assert.equal(error.code, enabled ? 1 : 2);
        const output = error.stdout + error.stderr;
        assert.match(output, enabled ? /webkit\.preflight\.start/ : /requires SWIFTWEB_BROWSER_E2E=1/);
        if (enabled) assert.match(output, /Executable doesn't exist/);
        assert.doesNotMatch(output, /server\.start|cli\.build|webkit\.preflight\.passed/);
        assert.equal(existsSync(appRoot), false);
        return true;
      });
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
}
