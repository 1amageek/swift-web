import Foundation
import HTTPTypes
import SwiftHTML
import SwiftWebCore

package enum SwiftWebDevHotReload {
  package static let reloadPath = "/__swiftweb/dev/reload"
  package static let eventsPath = "/__swiftweb/dev/events"
  package static let clientScriptPath = "/__swiftweb/dev/client.js"
  package static let reloadTokenHeaderName = HTTPField.Name("X-SwiftWeb-Dev-Token")!

  package static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["SWIFT_WEB_DEV"] == "1" && !token.isEmpty
  }

  package static var token: String {
    ProcessInfo.processInfo.environment["SWIFT_WEB_DEV_RELOAD_TOKEN"] ?? ""
  }

  package static func headers() -> HTTPFields {
    headers(isEnabled: isEnabled, token: token)
  }

  package static func headers(isEnabled: Bool, token: String) -> HTTPFields {
    guard isEnabled else {
      return [.contentType: "text/html; charset=utf-8"]
    }
    var headers: HTTPFields = [.contentType: "text/html; charset=utf-8"]
    headers[reloadTokenHeaderName] = token
    headers[.cacheControl] = "no-cache"
    return headers
  }

  @discardableResult
  package static func register(on routes: any RoutesBuilder) -> [Route] {
    guard isEnabled else {
      return []
    }

    let reloadRoute = routes.get("__swiftweb", "dev", "reload") { req async throws -> Response in
      let search = try URLEncodedFormDecoder().decode(SwiftWebDevReloadSearch.self, from: req.url.query ?? "")
      let currentToken = token
      var headers: HTTPFields = [
        .contentType: "text/plain; charset=utf-8",
        .cacheControl: "no-cache, no-transform",
      ]
      headers[reloadTokenHeaderName] = currentToken

      if search.token == currentToken {
        do {
          try await Task.sleep(nanoseconds: 60_000_000_000)
        } catch {
          if error is CancellationError {
            return Response(status: .noContent, headers: headers, body: .empty)
          }
          throw error
        }
      }

      return Response(headers: headers, body: .init(string: currentToken))
    }

    let eventsRoute = routes.get("__swiftweb", "dev", "events") { req async throws -> Response in
      let search = try URLEncodedFormDecoder().decode(SwiftWebDevEventsSearch.self, from: req.url.query ?? "")
      guard search.token == token else {
        return Response(
          status: .unauthorized,
          headers: [
            .contentType: "text/plain; charset=utf-8",
            .cacheControl: "no-cache, no-transform",
          ],
          body: .init(string: "invalid SwiftWeb dev event token")
        )
      }
      guard let eventLog = SwiftWebDevEventLog() else {
        throw Abort(.notFound, reason: "SwiftWeb dev event log is not configured")
      }

      let headers: HTTPFields = [
        .contentType: "text/event-stream; charset=utf-8",
        .cacheControl: "no-cache, no-transform",
      ]
      let payload = try await eventPayload(from: eventLog, after: search.lastEventID)
      return Response(headers: headers, body: .init(string: payload))
    }

    let clientScriptRoute = routes.get("__swiftweb", "dev", "client.js") { _ async throws -> Response in
      Response(headers: clientScriptHeaders(), body: .init(string: clientScript()))
    }

    return [reloadRoute, eventsRoute, clientScriptRoute]
  }

  package static func shouldSuppressRouteLog(for request: Request) -> Bool {
    request.url.path == reloadPath || request.url.path == eventsPath || request.url.path == clientScriptPath
  }

  package static func clientScriptHeaders() -> HTTPFields {
    [
      .contentType: "text/javascript; charset=utf-8",
      .cacheControl: "public, max-age=31536000, immutable",
    ]
  }

  private struct SwiftWebDevReloadSearch: Decodable {
    let token: String?
  }

  private struct SwiftWebDevEventsSearch: Decodable {
    let token: String?
    let lastEventID: String?
  }

  package static func sseData(for event: SwiftWebDevEvent) throws -> String {
    let data = try JSONEncoder.swiftWebDevEvent.encode(event)
    let json = String(decoding: data, as: UTF8.self)
    return SSEEvent(event: event.kind.rawValue, id: event.id, data: json).render()
  }

  package static func eventPayload(
    from eventLog: SwiftWebDevEventLog,
    after lastEventID: String?
  ) async throws -> String {
    if lastEventID == nil {
      if let latestEventID = try eventLog.latestEventID() {
        return try sseData(for: SwiftWebDevEvent(id: latestEventID, kind: .connected))
      }

      let connected = SwiftWebDevEvent(kind: .connected)
      try eventLog.append(connected)
      return try sseData(for: connected)
    }

    let deadline = Date().addingTimeInterval(30)
    while !Task.isCancelled {
      let events = try eventLog.events(after: lastEventID)
      if !events.isEmpty {
        return try events.map { event in
          try sseData(for: event)
        }.joined()
      }
      if Date() >= deadline {
        return ": swift-web-dev heartbeat\n\n"
      }
      try await Task.sleep(nanoseconds: 300_000_000)
    }

    throw CancellationError()
  }

  package static func inject(into html: String) -> String {
    inject(
      into: html,
      isEnabled: isEnabled,
      token: token,
      nonce: nil
    )
  }

  package static func inject(into html: String, nonce: String?) -> String {
    inject(
      into: html,
      isEnabled: isEnabled,
      token: token,
      nonce: nonce
    )
  }

  package static func inject(
    into html: String,
    isEnabled: Bool,
    token: String,
    nonce: String? = nil
  ) -> String {
    guard isEnabled else {
      return html
    }
    let markup = scriptMarkup(token: token, nonce: nonce)
    if let bodyEndRange = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
      var output = html
      output.insert(contentsOf: markup, at: bodyEndRange.lowerBound)
      return output
    }
    return html + markup
  }

  private static func scriptMarkup(token: String, nonce: String?) -> String {
    let nonceAttribute = nonce.map { " nonce=\"\(escapeHTMLAttribute($0))\"" } ?? ""
    let source = "\(clientScriptPath)?v=\(clientScriptVersion)"
    return """
      <script\(nonceAttribute)>
      globalThis.__swiftWebDevBootstrap = {
        token: "\(escapeJavaScriptString(token))",
        reloadPath: "\(reloadPath)",
        eventsPath: "\(eventsPath)"
      };
      </script>
      <script src="\(escapeHTMLAttribute(source))"\(nonceAttribute)></script>
      """
  }

  package static func clientScript() -> String {
    clientScriptSource
  }

  private static var clientScriptVersion: String {
    String(UInt(bitPattern: clientScriptSource.hashValue), radix: 16)
  }

  private static let clientScriptSource = """
      {
        const bootstrap = globalThis.__swiftWebDevBootstrap || {};
        const swiftWebDevToken = String(bootstrap.token || "");
        const swiftWebDevReloadURL = new URL(bootstrap.reloadPath || "/__swiftweb/dev/reload", window.location.href);
        const swiftWebDevEventsURL = new URL(bootstrap.eventsPath || "/__swiftweb/dev/events", window.location.href);
        swiftWebDevReloadURL.searchParams.set("token", swiftWebDevToken);
        swiftWebDevEventsURL.searchParams.set("token", swiftWebDevToken);
        const previous = globalThis.__swiftWebDevReload;
        if (previous && typeof previous.close === "function") {
          try {
            previous.close();
          } catch (_) {
          }
        }
        const state = {
          token: swiftWebDevToken,
          abortController: null,
          eventSource: null,
          reconnectTimer: null,
          connectedAt: null,
          lastEvent: null,
          lastEventAt: null,
          lastAppliedEvent: null,
          lastAppliedEventAt: null,
          lastError: null,
          close() {
            if (this.abortController) {
              this.abortController.abort();
            }
            if (this.eventSource) {
              this.eventSource.close();
            }
            if (this.reconnectTimer) {
              window.clearTimeout(this.reconnectTimer);
              this.reconnectTimer = null;
            }
          }
        };
        globalThis.__swiftWebDevReload = state;
        function devStatusColor(phase) {
          if (phase === "error" || phase === "failed") {
            return "#f87171";
          }
          if (phase === "reconnecting" || phase === "server" || phase === "client" || phase === "building") {
            return "#fbbf24";
          }
          if (phase === "style") {
            return "#60a5fa";
          }
          return "#34d399";
        }
        function ensureDevStatusElement() {
          let element = document.getElementById("devStatus");
          if (!element) {
            element = document.createElement("button");
            element.id = "devStatus";
            element.type = "button";
            element.setAttribute("aria-live", "polite");
            element.setAttribute("aria-label", "SwiftWeb development status");
            element.dataset.expanded = "false";
            element.style.cssText = [
              "position:fixed",
              "left:12px",
              "bottom:12px",
              "z-index:2147483647",
              "display:grid",
              "grid-template-columns:auto 1fr",
              "align-items:center",
              "gap:8px",
              "max-width:min(420px,calc(100vw - 24px))",
              "padding:8px 10px",
              "border:1px solid rgba(148,163,184,.32)",
              "border-radius:999px",
              "font:12px/1.35 -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif",
              "letter-spacing:0",
              "text-align:left",
              "box-shadow:0 10px 30px rgba(15,23,42,.18)",
              "background:rgba(15,23,42,.88)",
              "color:white",
              "backdrop-filter:saturate(1.4) blur(12px)",
              "-webkit-backdrop-filter:saturate(1.4) blur(12px)",
              "cursor:default",
              "pointer-events:auto"
            ].join(";");
            element.addEventListener("click", () => {
              element.dataset.expanded = element.dataset.expanded === "true" ? "false" : "true";
              renderDevStatus();
            });
            document.documentElement.appendChild(element);
          }
          return element;
        }
        function renderDevStatus() {
          const element = ensureDevStatusElement();
          const current = state.status || {
            phase: "connecting",
            message: "SwiftWeb dev connecting",
            detail: ""
          };
          const phase = current.phase || "info";
          element.dataset.phase = phase;
          const isExpanded = element.dataset.expanded === "true" || phase === "error" || phase === "failed";
          const dot = document.createElement("span");
          dot.style.cssText = [
            "width:8px",
            "height:8px",
            "border-radius:999px",
            `background:${devStatusColor(phase)}`,
            "box-shadow:0 0 0 3px rgba(255,255,255,.09)"
          ].join(";");
          const text = document.createElement("span");
          text.style.cssText = [
            "display:grid",
            "gap:2px",
            "min-width:0"
          ].join(";");
          const label = document.createElement("span");
          label.textContent = current.message || "SwiftWeb dev";
          label.style.cssText = [
            "font-weight:650",
            "white-space:nowrap",
            "overflow:hidden",
            "text-overflow:ellipsis"
          ].join(";");
          text.appendChild(label);
          if (isExpanded && current.detail) {
            const detail = document.createElement("span");
            detail.textContent = current.detail;
            detail.style.cssText = [
              "max-width:360px",
              "white-space:normal",
              "color:rgba(255,255,255,.72)"
            ].join(";");
            text.appendChild(detail);
          }
          element.replaceChildren(dot, text);
        }
        function showDevStatus(message, phase = "info", detail = "") {
          state.status = { message, phase, detail };
          renderDevStatus();
        }
        function handleWasmStatus(status) {
          if (!status) {
            return;
          }
          if (status.error) {
            showDevStatus("Client WASM failed", "failed", String(status.error));
            return;
          }
          if (status.ready === true) {
            showDevStatus("SwiftWeb ready", "connected", "HMR connected. Client WASM ready.");
            return;
          }
          const phase = String(status.phase || "loading");
          showDevStatus(`Client WASM ${phase}`, "client", "ClientComponent actions are waiting for the WASM runtime.");
        }
        window.addEventListener("wasmStatus", (event) => {
          handleWasmStatus(event.detail);
        });
        window.setTimeout(() => {
          if (window.__swiftWebWasmRuntimeStatus) {
            handleWasmStatus(window.__swiftWebWasmRuntimeStatus);
          } else {
            const hasWasmRuntime = Boolean(document.getElementById("client-runtime"));
            showDevStatus(
              "SwiftWeb dev connecting",
              "reconnecting",
              hasWasmRuntime
                ? "Waiting for HMR and Client WASM runtime status."
                : "Waiting for the HMR event stream."
            );
          }
        }, 0);
        function swiftWebApplyStylePatch(patch) {
          if (!patch || typeof patch.css !== "string") {
            return;
          }
          const id = patch.id || "dev-style-hmr";
          let element = document.getElementById(id);
          if (!element) {
            element = document.createElement("style");
            element.id = id;
            document.head.appendChild(element);
          }
          element.textContent = patch.css;
          showDevStatus("SwiftWeb HMR: style patch applied", "style");
        }
        function swiftWebSleep(milliseconds) {
          return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
        }
        function swiftWebDispatchSSEMessage(message) {
          if (!message || !message.data.length) {
            return;
          }
          const payloadText = message.data.join("\\n");
          swiftWebHandleDevEvent(JSON.parse(payloadText)).catch((error) => {
            state.lastError = String(error && error.message ? error.message : error);
            console.error("SwiftWeb HMR event failed", error);
            showDevStatus(String(error && error.message ? error.message : error), "error");
          });
        }
        function swiftWebParseSSEChunk(buffer, onMessage) {
          let cursor = 0;
          while (true) {
            const next = buffer.indexOf("\\n", cursor);
            if (next === -1) {
              return buffer.slice(cursor);
            }
            let line = buffer.slice(cursor, next);
            cursor = next + 1;
            if (line.endsWith("\\r")) {
              line = line.slice(0, -1);
            }
            if (line.length === 0) {
              onMessage();
              continue;
            }
            if (line.startsWith(":")) {
              continue;
            }
            const separator = line.indexOf(":");
            const field = separator === -1 ? line : line.slice(0, separator);
            const value = separator === -1
              ? ""
              : line.slice(separator + 1).replace(/^ /, "");
            onMessage(field, value);
          }
        }
        async function swiftWebHandleDevEvent(payload) {
          if (!payload || !payload.kind) {
            return;
          }
          state.lastEvent = payload;
          state.lastEventAt = Date.now();
          if (payload.kind === "connected") {
            showDevStatus("SwiftWeb HMR connected", "connected");
            state.lastAppliedEvent = payload;
            state.lastAppliedEventAt = Date.now();
            return;
          }
          if (payload.kind === "stylePatch") {
            swiftWebApplyStylePatch(payload.stylePatch);
            state.lastAppliedEvent = payload;
            state.lastAppliedEventAt = Date.now();
            return;
          }
          if (payload.kind === "clientBuildStarted") {
            showDevStatus("Client WASM rebuilding", "client", "ClientComponent actions keep the previous runtime until the new bundle is ready.");
            state.lastAppliedEvent = payload;
            state.lastAppliedEventAt = Date.now();
            return;
          }
          if (payload.kind === "clientComponentUpdate") {
            const runtime = window.__swiftWebWasmRuntime;
            if (runtime && typeof runtime.applyHotUpdate === "function") {
              await runtime.applyHotUpdate(payload.clientComponentUpdate);
              showDevStatus("SwiftWeb HMR: client component updated", "client");
              state.lastAppliedEvent = payload;
              state.lastAppliedEventAt = Date.now();
              return;
            }
            window.location.reload();
            return;
          }
          if (payload.kind === "serverBuildStarted") {
            showDevStatus("SwiftWeb HMR: server rebuilding", "server");
            state.lastAppliedEvent = payload;
            state.lastAppliedEventAt = Date.now();
            return;
          }
          if (payload.kind === "serverRestarted" || payload.kind === "pagePatch") {
            const runtime = window.__swiftWebWasmRuntime;
            if (runtime && typeof runtime.invalidateServerDocument === "function") {
              await runtime.invalidateServerDocument(window.location.href);
              showDevStatus("SwiftWeb HMR: page patched", "server");
              state.lastAppliedEvent = payload;
              state.lastAppliedEventAt = Date.now();
              return;
            }
            window.location.reload();
            return;
          }
          if (payload.kind === "fullReload") {
            window.location.reload();
            return;
          }
          if (payload.kind === "error") {
            showDevStatus(payload.message || "SwiftWeb HMR error", "error");
            state.lastAppliedEvent = payload;
            state.lastAppliedEventAt = Date.now();
          }
        }
        function swiftWebStartFetchEventStream() {
          if (!("fetch" in window) || !("TextDecoder" in window)) {
            return false;
          }
          let lastEventID = null;
          const streamState = {
            readyState: 0,
            close() {
              this.readyState = 2;
              if (state.abortController) {
                state.abortController.abort();
              }
            }
          };
          state.eventSource = streamState;
          const run = async () => {
            while (globalThis.__swiftWebDevReload === state && streamState.readyState !== 2) {
              const controller = new AbortController();
              state.abortController = controller;
              const url = new URL(swiftWebDevEventsURL.href);
              if (lastEventID) {
                url.searchParams.set("lastEventID", lastEventID);
              }
                try {
                  const response = await fetch(url.href, {
                    cache: "no-store",
                    credentials: "same-origin",
                    headers: { "Accept": "text/event-stream" },
                    signal: controller.signal
                  });
                  if (!response.ok || !response.body) {
                    if (response.status === 401 || response.status === 403) {
                      showDevStatus("SwiftWeb dev session changed", "reconnecting", "Reloading to reconnect with the current dev server token.");
                      window.location.reload();
                      return;
                    }
                    throw new Error(`SwiftWeb HMR stream failed with ${response.status}`);
                  }
                streamState.readyState = 1;
                state.connectedAt = Date.now();
                state.lastError = null;
                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = "";
                let message = { event: "message", id: null, data: [] };
                const flush = (field, value) => {
                  if (field === undefined) {
                    if (message.id) {
                      lastEventID = message.id;
                    }
                    swiftWebDispatchSSEMessage(message);
                    message = { event: "message", id: null, data: [] };
                    return;
                  }
                  if (field === "event") {
                    message.event = value;
                  } else if (field === "id") {
                    message.id = value;
                  } else if (field === "data") {
                    message.data.push(value);
                  }
                };
                while (globalThis.__swiftWebDevReload === state) {
                  const result = await reader.read();
                  if (result.done) {
                    break;
                  }
                  buffer += decoder.decode(result.value, { stream: true });
                  buffer = swiftWebParseSSEChunk(buffer, flush);
                }
                streamState.readyState = 0;
              } catch (error) {
                if (controller.signal.aborted || globalThis.__swiftWebDevReload !== state) {
                  return;
                }
                streamState.readyState = 0;
                state.lastError = String(error && error.message ? error.message : error);
                showDevStatus("SwiftWeb HMR reconnecting", "reconnecting");
              }
              await swiftWebSleep(500);
            }
          };
          run();
          return true;
        }
        function swiftWebStartEventStream() {
          if (!("EventSource" in window)) {
            return false;
          }
          const source = new EventSource(swiftWebDevEventsURL.href, { withCredentials: true });
          state.eventSource = source;
          source.onopen = () => {
            state.connectedAt = Date.now();
            state.lastError = null;
            if (state.reconnectTimer) {
              window.clearTimeout(state.reconnectTimer);
              state.reconnectTimer = null;
            }
            if (state.abortController) {
              state.abortController.abort();
              state.abortController = null;
            }
          };
          const handleEvent = (event) => {
            try {
              if (!event || typeof event.data !== "string" || event.data.length === 0) {
                return;
              }
              swiftWebHandleDevEvent(JSON.parse(event.data)).catch((error) => {
                state.lastError = String(error && error.message ? error.message : error);
                console.error("SwiftWeb HMR event failed", error);
                showDevStatus(String(error && error.message ? error.message : error), "error");
              });
            } catch (error) {
              state.lastError = String(error && error.message ? error.message : error);
              console.error("SwiftWeb HMR event parse failed", error);
            }
          };
          for (const name of [
            "connected",
            "stylePatch",
            "clientBuildStarted",
            "clientComponentUpdate",
            "serverBuildStarted",
            "serverRestarted",
            "pagePatch",
            "fullReload",
            "error"
          ]) {
            source.addEventListener(name, handleEvent);
          }
          source.onerror = () => {
            state.lastError = `EventSource error: readyState=${source.readyState}`;
            if (globalThis.__swiftWebDevReload === state && !state.reconnectTimer) {
              state.reconnectTimer = window.setTimeout(() => {
                state.reconnectTimer = null;
                if (globalThis.__swiftWebDevReload !== state) {
                  return;
                }
                if (source.readyState === EventSource.CLOSED) {
                  showDevStatus("SwiftWeb HMR reconnecting", "reconnecting");
                  source.close();
                  if (state.eventSource === source) {
                    state.eventSource = null;
                  }
                  swiftWebStartEventStream();
                } else if (source.readyState !== EventSource.OPEN) {
                  showDevStatus("SwiftWeb HMR reconnecting", "reconnecting");
                }
              }, 1200);
            }
          };
          return true;
        }
        async function swiftWebWaitForReload() {
          if (globalThis.__swiftWebDevReload !== state) {
            return;
          }
          const controller = new AbortController();
          state.abortController = controller;
          try {
            const response = await fetch(swiftWebDevReloadURL.href, {
              cache: "no-store",
              credentials: "same-origin",
              signal: controller.signal
            });
            const headerToken = response.headers.get("X-SwiftWeb-Dev-Token");
            const bodyToken = (await response.text()).trim();
            const nextToken = bodyToken || headerToken;
            if (nextToken && nextToken !== swiftWebDevToken) {
              window.location.reload();
              return;
            }
          } catch (_) {
          }
          if (globalThis.__swiftWebDevReload === state) {
            window.setTimeout(swiftWebWaitForReload, 300);
          }
        }
        if (!swiftWebStartFetchEventStream() && !swiftWebStartEventStream()) {
          swiftWebWaitForReload();
        }
      }
      """

  private static func escapeJavaScriptString(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "<", with: "\\u003C")
  }

  private static func escapeHTMLAttribute(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}
