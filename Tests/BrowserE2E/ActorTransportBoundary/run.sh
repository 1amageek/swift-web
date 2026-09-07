#!/bin/bash
set -euo pipefail
fixture="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$fixture/../../.." && pwd)"
swift=/Users/1amageek/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a.xctoolchain/usr/bin/swift
sdk=swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a_wasm
guard="$root/scripts/swift-test-timeout.sh"
scratch="$root/.swiftweb/actor-transport-boundary-build"
profile="${1:-standard}"
profile_flags=(-Xswiftc -Onone)
case "$profile" in
  standard) ;;
  embedded)
    sdk="$sdk-embedded"
    scratch="$scratch-embedded"
    configuration="$("$guard" 60 "$swift" sdk configure --show-configuration "$sdk" wasm32-unknown-wasip1)"
    printf '%s\n' "$configuration"
    resources="$(printf '%s\n' "$configuration" | sed -n 's/^swiftResourcesPath: //p')"
    unicode="$resources/embedded/wasm32-unknown-wasip1/libswiftUnicodeDataTables.a"
    test -f "$unicode"
    profile_flags+=(-Xlinker "-L$(dirname "$unicode")")
    ;;
  *) printf 'Expected standard or embedded profile.\n' >&2; exit 64 ;;
esac
printf 'Toolchain: %s\nSDK: %s\nSource: ' "$swift" "$sdk"
git -C "$root" rev-parse HEAD
df -h "$root"
"$swift" --version
# The SDK owns Embedded/WMO; JavaScriptKit's optional empty-object mode is not used.
env -u SWIFT_WEB_ROOT SWIFTWEB_CORE_ONLY=1 SWIFTWEB_BOUNDARY_PROFILE="$profile" JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM=false "$guard" 1200 "$swift" build \
  --package-path "$fixture" --scratch-path "$scratch" --swift-sdk "$sdk" --jobs 2 \
  --build-system native --product ActorTransportBoundary --disable-index-store "${profile_flags[@]}"
if [ "$profile" = embedded ]; then
  node --input-type=module - "$scratch/wasm32-unknown-wasip1/debug/description.json" <<'JS'
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const commands = JSON.parse(readFileSync(process.argv[2])).swiftCommands;
const command = commands['C.ActorTransportBoundary-wasm32-unknown-wasip1-debug.module'];
assert(command.otherArguments.includes('Embedded'));
assert(command.otherArguments.includes('-wmo'));
assert(command.otherArguments.includes('-Onone'));
console.log('Verified Embedded Debug/WMO compiler arguments');
JS
fi
node --input-type=module - "$scratch/workspace-state.json" <<'JS'
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import assert from 'node:assert/strict';
const dependencies = JSON.parse(readFileSync(process.argv[2])).object.dependencies;
for (const [identity, version, revision] of [
  ['javascriptkit', '0.57.3', '166dc39b6e282a0f039762381332ba6333ec809c'],
  ['swift-actor-system', '0.2.0', 'cdbca08b3a08d3cd5620ae16b5c33c372aff1ad3'],
]) {
  const entry = dependencies.find(value => value.packageRef.identity.toLowerCase() === identity);
  assert.equal(entry?.state.name, 'sourceControlCheckout');
  assert.equal(entry.state.checkoutState.version, version);
  assert.equal(entry.state.checkoutState.branch, undefined);
  assert.equal(entry.state.checkoutState.revision, revision);
}
const scratch = dirname(process.argv[2]);
const checkout = join(scratch, 'checkouts/JavaScriptKit');
assert.equal(execFileSync('git', ['-C', checkout, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  '166dc39b6e282a0f039762381332ba6333ec809c');
const commands = JSON.parse(readFileSync(join(scratch, 'wasm32-unknown-wasip1/debug/description.json'))).swiftCommands;
const eventLoop = Object.values(commands).find(command => command.moduleName === 'JavaScriptEventLoop');
assert(eventLoop.sources.includes(join(checkout, 'Sources/JavaScriptEventLoop/JavaScriptEventLoop.swift')));
console.log('Verified public JavaScriptKit checkout and compiled source path');
JS
"$guard" 60 node "$fixture/run.mjs" \
  "$scratch/wasm32-unknown-wasip1/debug/ActorTransportBoundary.wasm" \
  "$scratch/checkouts/JavaScriptKit"
