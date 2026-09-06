import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { promisify } from "node:util";

const execute = promisify(execFile);
const runner = fileURLToPath(new URL("./counter-wasm-runtime-e2e.mjs", import.meta.url));

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
