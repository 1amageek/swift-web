import Foundation
import HTTPTypes
import SwiftHTML
import SwiftWeb
import Vapor

enum SwiftWebDevHotReload {
    static let reloadPath = "/__swiftweb/dev/reload"
    static let eventsPath = "/__swiftweb/dev/events"
    static let reloadTokenHeaderName = HTTPField.Name("X-SwiftWeb-Dev-Token")!

    static var isEnabled: Bool {
        Vapor.Environment.get("SWIFT_WEB_DEV") == "1" && !token.isEmpty
    }

    static var token: String {
        Vapor.Environment.get("SWIFT_WEB_DEV_RELOAD_TOKEN") ?? ""
    }

    static func headers() -> HTTPFields {
        headers(isEnabled: isEnabled, token: token)
    }

    static func headers(isEnabled: Bool, token: String) -> HTTPFields {
        guard isEnabled else {
            return [.contentType: "text/html; charset=utf-8"]
        }
        var headers: HTTPFields = [.contentType: "text/html; charset=utf-8"]
        headers[reloadTokenHeaderName] = token
        headers[.cacheControl] = "no-cache"
        return headers
    }

    @discardableResult
    static func register(on routes: any RoutesBuilder) -> [Route] {
        guard isEnabled else {
            return []
        }

        let reloadRoute = routes.get("__swiftweb", "dev", "reload") { req async throws -> Response in
            let search = try req.query.decode(SwiftWebDevReloadSearch.self)
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
            let search = try req.query.decode(SwiftWebDevEventsSearch.self)
            guard search.token == token else {
                throw Abort(.unauthorized, reason: "invalid SwiftWeb dev event token")
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

        return [reloadRoute, eventsRoute]
    }

    static func shouldSuppressRouteLog(for request: Request) -> Bool {
        request.url.path == reloadPath || request.url.path == eventsPath
    }

    private struct SwiftWebDevReloadSearch: Decodable {
        let token: String?
    }

    private struct SwiftWebDevEventsSearch: Decodable {
        let token: String?
        let lastEventID: String?
    }

    private static func sseData(for event: SwiftWebDevEvent) throws -> String {
        let data = try JSONEncoder.swiftWebDevEvent.encode(event)
        let json = String(decoding: data, as: UTF8.self)
        return SSEEvent(event: event.kind.rawValue, id: event.id, data: json).render()
    }

    static func eventPayload(
        from eventLog: SwiftWebDevEventLog,
        after lastEventID: String?
    ) async throws -> String {
        if lastEventID == nil {
            return try sseData(for: SwiftWebDevEvent(kind: .connected))
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

    static func inject(into html: String) -> String {
        inject(
            into: html,
            isEnabled: isEnabled,
            token: token,
            nonce: nil
        )
    }

    static func inject(into html: String, nonce: String?) -> String {
        inject(
            into: html,
            isEnabled: isEnabled,
            token: token,
            nonce: nonce
        )
    }

    static func inject(
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
        return """
        <script type="module"\(nonceAttribute)>
        {
          const swiftWebDevToken = "\(escapeJavaScriptString(token))";
          const swiftWebDevReloadURL = new URL("\(reloadPath)", window.location.href);
          const swiftWebDevEventsURL = new URL("\(eventsPath)", window.location.href);
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
          function swiftWebDevOverlay(message, phase = "info") {
            let element = document.getElementById("hmr-status");
            if (!element) {
              element = document.createElement("div");
              element.id = "hmr-status";
              element.style.cssText = [
                "position:fixed",
                "right:12px",
                "bottom:12px",
                "z-index:2147483647",
                "max-width:420px",
                "padding:10px 12px",
                "border-radius:10px",
                "font:12px/1.35 -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif",
                "box-shadow:0 8px 30px rgba(15,23,42,.18)",
                "background:rgba(15,23,42,.92)",
                "color:white",
                "pointer-events:none"
              ].join(";");
              document.documentElement.appendChild(element);
            }
            element.textContent = message;
            element.dataset.phase = phase;
            window.clearTimeout(element.__swiftWebDevTimer);
            if (phase !== "error") {
              element.__swiftWebDevTimer = window.setTimeout(() => element.remove(), 2200);
            }
          }
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
            swiftWebDevOverlay("SwiftWeb HMR: style patch applied", "style");
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
              swiftWebDevOverlay(String(error && error.message ? error.message : error), "error");
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
              swiftWebDevOverlay("SwiftWeb HMR connected", "connected");
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
            if (payload.kind === "clientComponentUpdate") {
              const runtime = window.__swiftWebWasmRuntime;
              if (runtime && typeof runtime.applyHotUpdate === "function") {
                await runtime.applyHotUpdate(payload.clientComponentUpdate);
                swiftWebDevOverlay("SwiftWeb HMR: client component updated", "client");
                state.lastAppliedEvent = payload;
                state.lastAppliedEventAt = Date.now();
                return;
              }
              window.location.reload();
              return;
            }
            if (payload.kind === "serverBuildStarted") {
              swiftWebDevOverlay("SwiftWeb HMR: server rebuilding", "server");
              state.lastAppliedEvent = payload;
              state.lastAppliedEventAt = Date.now();
              return;
            }
            if (payload.kind === "serverRestarted" || payload.kind === "pagePatch") {
              const runtime = window.__swiftWebWasmRuntime;
              if (runtime && typeof runtime.invalidateServerDocument === "function") {
                await runtime.invalidateServerDocument(window.location.href);
                swiftWebDevOverlay("SwiftWeb HMR: page patched", "server");
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
              swiftWebDevOverlay(payload.message || "SwiftWeb HMR error", "error");
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
                  swiftWebDevOverlay("SwiftWeb HMR reconnecting", "reconnecting");
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
                  swiftWebDevOverlay(String(error && error.message ? error.message : error), "error");
                });
              } catch (error) {
                state.lastError = String(error && error.message ? error.message : error);
                console.error("SwiftWeb HMR event parse failed", error);
              }
            };
            for (const name of [
              "connected",
              "stylePatch",
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
                    swiftWebDevOverlay("SwiftWeb HMR reconnecting", "reconnecting");
                    source.close();
                    if (state.eventSource === source) {
                      state.eventSource = null;
                    }
                    swiftWebStartEventStream();
                  } else if (source.readyState !== EventSource.OPEN) {
                    swiftWebDevOverlay("SwiftWeb HMR reconnecting", "reconnecting");
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
        </script>
        """
    }

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
