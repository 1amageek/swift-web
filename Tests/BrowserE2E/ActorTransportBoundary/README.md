# Actor transport boundary probe

This test-only Standard/Embedded WASM executable directly uses the public
`JavaScriptKitActorTransport` selected by `ClientRuntimeActorSystemFactory`, and
`ActorFrameCodec`. It does not replace or copy the transport. The root SwiftWeb
package is the source under measurement; ActorSystem and JavaScriptKit use exact
public versions in this fixture's manifest: ActorSystem 0.2.0 and JavaScriptKit
0.57.3. The before-copy baseline used
JavaScriptKit 0.57.2 (`8067be4d2f907ab4a25614272f9e531fddd2ecfe`), matching the
verified CounterApp WASM source. The adopted JavaScriptKit 0.57.3 release is
`166dc39b6e282a0f039762381332ba6333ec809c`, including the Embedded WASI executor
integration. The root adoption also includes the already-reviewed 0.57.2 changes
since its older 0.57.0 resolution; that older resolution was not the measured
browser baseline.

```text
Swift codec -> actual transport -> measured JavaScriptKit ABI -> opaque JS reply
Swift codec <- actual transport <- measured JavaScriptKit ABI <- codec result
```

Run from the repository root with Playwright installed in `Tests/BrowserE2E`,
system Chrome, and an installed esbuild dependency tree. Set
`SWIFT_WEB_NODE_MODULES` to that tree's absolute `node_modules` directory (the
verified baseline used esbuild 0.28.1). No specific temporary directory is a
prerequisite:

```sh
export SWIFT_WEB_NODE_MODULES=/absolute/path/to/installed/node_modules
bash Tests/BrowserE2E/ActorTransportBoundary/run.sh standard
bash Tests/BrowserE2E/ActorTransportBoundary/run.sh embedded
```

The runner uses the pinned August 14 Swift 6.4 snapshot and matching WASM SDKs,
separate profile scratch directories, Debug/native SwiftPM backend, jobs 2, a 1200-second build guard and a 60-second
browser guard. It verifies exact public versions, reviewed checkout revisions,
and compiled source paths, bundles the exact JavaScriptKit
runtime, and reuses the production `SwiftWebWASI` class bytes. Browser, listener,
and failure diagnostics belong to the runner. SwiftWeb dependency traits are
disabled in both profiles: this directly exercises the common HTTP transport,
not an authored distributed actor or the page-worker deployment. Embedded uses
its SDK's mandatory Embedded/WMO flags and matching Unicode archive; JavaScriptKit's
optional empty-object mode is explicitly disabled. There is no Native dev server,
network performance assertion, or new latency SLO in this boundary probe.

The four success cases are zero/1 MiB payloads through fetch and the optional
host-request branch. Both frame directions are produced by Swift's real codec;
JavaScript compares/returns opaque bytes, without implementing a wire format.
Each case also checks HTTP 503, empty response rejection, in-flight cancellation,
stream completion and rejection after shutdown. Fixture setup is excluded from
the measured success interval. The fetch/host functions are controlled boundary
peers, not proof of real HTTP/DO routing; existing native HTTP/WSS tests own those
separate boundaries.

| Accounting | Evidence |
| --- | --- |
| Swift to JS | Actual `swjs_create_typed_array` calls and byte lengths |
| JS to Swift | Actual `swjs_copy_typed_array_bytes` calls and byte capacities |
| Swift intermediate arrays | Exact source accounting on the executed transport path; not allocator instrumentation |
| Native retained storage/range | Existing `SwiftWebHostActorBinaryChannelTests` and `SwiftWebHTTPServerHostTests` 1 MiB probes |
| HTTP collection and WSS echo | Existing real-server tests, including 1 MiB equality |

The gate expects one outbound ABI copy for both fetch and the host-request
branch. The retained unmodified baseline used `SWIFTWEB_EXPECT_HOST_COPIES=2`
for the host-request branch. Both expect one inbound ABI copy. These counters
do not count JS `Response` allocation, Swift internal array materialization,
encryption, network stacks, or all process allocations. Copy semantics are owned
by [the ClientRuntime design](../../../Sources/SwiftWebBrowser/ClientRuntime/DESIGN.md).

Both pinned Debug profiles passed all four cases in Chromium against the exact
public JavaScriptKit revision, with no edit override: byte equality, HTTP 503
as `overloaded`, empty response as `invalidFrame`, in-flight `cancelled`, and
post-shutdown `transportClosed` plus stream completion. Each profile reported
four aborted requests, empty browser/console/request-error arrays, and completed
browser/listener cleanup. Embedded additionally verifies SDK Embedded/WMO flags;
the compiled installation calls the executor factory before retaining legacy
compatibility entries. Its detached-to-MainActor hop now reaches the transport.
This is a controlled JavaScript ABI proof, not a generated Embedded page,
real network Actor service, full browser E2E, or deployment proof.
