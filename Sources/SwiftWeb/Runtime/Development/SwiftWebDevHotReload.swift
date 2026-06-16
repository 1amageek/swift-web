import Foundation
import HTTPTypes
import SwiftHTML
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
            return Response(
                headers: headers,
                body: .init(asyncStream: { writer in
                    let streamWriter = StreamWriter(writer, environment: EnvironmentValues())
                    var lastEventID = search.lastEventID
                    var lastHeartbeat = Date()
                    do {
                        let connected = SwiftWebDevEvent(kind: .connected)
                        try await streamWriter.write(try sseData(for: connected))

                        while !Task.isCancelled {
                            let events = try eventLog.events(after: lastEventID)
                            for event in events {
                                try await streamWriter.write(try sseData(for: event))
                                lastEventID = event.id
                            }
                            let now = Date()
                            if now.timeIntervalSince(lastHeartbeat) >= 10 {
                                try await streamWriter.write(": swift-web-dev heartbeat\n\n")
                                lastHeartbeat = now
                            }
                            try await Task.sleep(nanoseconds: 300_000_000)
                        }
                        try await writer.write(.end)
                    } catch is CancellationError {
                        try await writer.write(.end)
                    } catch {
                        req.application.logger.error("SwiftWeb dev event stream failed: \(String(describing: error))")
                        try await writer.write(.error(error))
                    }
                })
            )
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
            let element = document.getElementById("swift-web-dev-hmr-status");
            if (!element) {
              element = document.createElement("div");
              element.id = "swift-web-dev-hmr-status";
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
            const id = patch.id || "swift-web-dev-style-hmr";
            let element = document.getElementById(id);
            if (!element) {
              element = document.createElement("style");
              element.id = id;
              document.head.appendChild(element);
            }
            element.textContent = patch.css;
            swiftWebDevOverlay("SwiftWeb HMR: style patch applied", "style");
          }
          async function swiftWebHandleDevEvent(payload) {
            if (!payload || !payload.kind) {
              return;
            }
            if (payload.kind === "connected") {
              swiftWebDevOverlay("SwiftWeb HMR connected", "connected");
              return;
            }
            if (payload.kind === "stylePatch") {
              swiftWebApplyStylePatch(payload.stylePatch);
              return;
            }
            if (payload.kind === "clientComponentUpdate") {
              const runtime = window.__swiftWebWasmRuntime;
              if (runtime && typeof runtime.applyHotUpdate === "function") {
                await runtime.applyHotUpdate(payload.clientComponentUpdate);
                swiftWebDevOverlay("SwiftWeb HMR: client component updated", "client");
                return;
              }
              window.location.reload();
              return;
            }
            if (payload.kind === "serverBuildStarted") {
              swiftWebDevOverlay("SwiftWeb HMR: server rebuilding", "server");
              return;
            }
            if (payload.kind === "serverRestarted" || payload.kind === "pagePatch") {
              const runtime = window.__swiftWebWasmRuntime;
              if (runtime && typeof runtime.invalidateServerDocument === "function") {
                await runtime.invalidateServerDocument(window.location.href);
                swiftWebDevOverlay("SwiftWeb HMR: page patched", "server");
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
            }
          }
          function swiftWebStartEventStream() {
            if (!("EventSource" in window)) {
              return false;
            }
            const source = new EventSource(swiftWebDevEventsURL.href, { withCredentials: true });
            state.eventSource = source;
            source.onopen = () => {
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
                swiftWebHandleDevEvent(JSON.parse(event.data)).catch((error) => {
                  console.error("SwiftWeb HMR event failed", error);
                  swiftWebDevOverlay(String(error && error.message ? error.message : error), "error");
                });
              } catch (error) {
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
              if (globalThis.__swiftWebDevReload === state && !state.reconnectTimer) {
                state.reconnectTimer = window.setTimeout(() => {
                  state.reconnectTimer = null;
                  if (globalThis.__swiftWebDevReload !== state) {
                    return;
                  }
                  if (source.readyState !== EventSource.OPEN) {
                    swiftWebDevOverlay("SwiftWeb HMR reconnecting", "reconnecting");
                    source.close();
                    if (state.eventSource === source) {
                      state.eventSource = null;
                    }
                    swiftWebWaitForReload();
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
          if (!swiftWebStartEventStream()) {
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
