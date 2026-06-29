import SwiftHTML

package enum SwiftWebWasmRuntimeHostScript {
  package static let source = #"""
    const swiftWebRuntimeMarkers = Object.freeze({
      nodeAttribute: "\#(HTMLRuntimeMarkers.nodeAttribute)",
      keyAttribute: "\#(HTMLRuntimeMarkers.keyAttribute)",
      eventAttributePrefix: "\#(HTMLRuntimeMarkers.eventAttributePrefix)",
      componentCommentPrefix: "\#(HTMLRuntimeMarkers.componentCommentPrefix)",
      serverSlotCommentPrefix: "\#(HTMLRuntimeMarkers.serverSlotCommentPrefix)"
    });

    const swiftWebEventNames = [
      "click",
      "input",
      "change",
      "submit",
      "close",
      "keydown",
      "keyup",
      "focus",
      "blur",
      "mousedown",
      "mouseup",
      "mousemove",
      "mouseenter",
      "mouseleave",
      "pointerdown",
      "pointerup",
      "pointermove",
      "pointerenter",
      "pointerleave",
      "dragstart",
      "dragover",
      "drop",
      "reset",
      "invalid",
      "load",
      "error",
      "scroll"
    ];

    const swiftWebJavaScriptKitRuntimeModules = new Map();

    async function swiftWebLoadJavaScriptKitRuntime(path) {
      if (!swiftWebJavaScriptKitRuntimeModules.has(path)) {
        swiftWebJavaScriptKitRuntimeModules.set(path, import(path));
      }
      return await swiftWebJavaScriptKitRuntimeModules.get(path);
    }

    function swiftWebBridgeJSStubs() {
      const unexpectedBridgeJSCall = () => {
        throw new Error("BridgeJS import was called, but SwiftWeb has not configured BridgeJS for this client bundle.");
      };
      return {
        swift_js_return_string: unexpectedBridgeJSCall,
        swift_js_init_memory: unexpectedBridgeJSCall,
        swift_js_make_js_string: unexpectedBridgeJSCall,
        swift_js_init_memory_with_result: unexpectedBridgeJSCall,
        swift_js_throw: unexpectedBridgeJSCall,
        swift_js_retain: unexpectedBridgeJSCall,
        swift_js_release: unexpectedBridgeJSCall,
        swift_js_push_i32: unexpectedBridgeJSCall,
        swift_js_push_f32: unexpectedBridgeJSCall,
        swift_js_push_f64: unexpectedBridgeJSCall,
        swift_js_push_string: unexpectedBridgeJSCall,
        swift_js_pop_i32: unexpectedBridgeJSCall,
        swift_js_pop_f32: unexpectedBridgeJSCall,
        swift_js_pop_f64: unexpectedBridgeJSCall,
        swift_js_return_optional_bool: unexpectedBridgeJSCall,
        swift_js_return_optional_int: unexpectedBridgeJSCall,
        swift_js_return_optional_string: unexpectedBridgeJSCall,
        swift_js_return_optional_double: unexpectedBridgeJSCall,
        swift_js_return_optional_float: unexpectedBridgeJSCall,
        swift_js_return_optional_heap_object: unexpectedBridgeJSCall,
        swift_js_return_optional_object: unexpectedBridgeJSCall,
        swift_js_get_optional_int_presence: unexpectedBridgeJSCall,
        swift_js_get_optional_int_value: unexpectedBridgeJSCall,
        swift_js_get_optional_string: unexpectedBridgeJSCall,
        swift_js_get_optional_float_presence: unexpectedBridgeJSCall,
        swift_js_get_optional_float_value: unexpectedBridgeJSCall,
        swift_js_get_optional_double_presence: unexpectedBridgeJSCall,
        swift_js_get_optional_double_value: unexpectedBridgeJSCall,
        swift_js_get_optional_heap_object_pointer: unexpectedBridgeJSCall,
        swift_js_push_pointer: unexpectedBridgeJSCall,
        swift_js_pop_pointer: unexpectedBridgeJSCall,
        swift_js_push_i64: unexpectedBridgeJSCall,
        swift_js_pop_i64: unexpectedBridgeJSCall,
        swift_js_closure_unregister: unexpectedBridgeJSCall,
        swift_js_push_typed_array: unexpectedBridgeJSCall,
        swift_js_make_promise: unexpectedBridgeJSCall
      };
    }

    class SwiftWebWasmRuntime {
      constructor(descriptor) {
        this.descriptor = descriptor;
        this.configuration = descriptor.wasm;
        this.security = descriptor.security || {};
        this.hydrationIndex = descriptor.hydrationIndex || null;
        this.documentHydrationIndex = descriptor.hydrationIndex || null;
        this.manifest = null;
        this.instances = new Map();
        this.loading = new Map();
        this.loadedBundleIDs = new Set();
        this.eventQueue = Promise.resolve();
        this.coalescedInputEvents = new Map();
        this.coalescedInputFlushActive = false;
        this.coalescedInputFlushScheduled = false;
        this.primaryInstance = null;
        this.primaryBundleID = null;
        this.swiftRuntimes = new Map();
        this.bootstrappedBundleIDs = new Set();
        this.currentDocumentURL = window.location.href;
        this.metrics = this.createMetrics();
        this.recordMetric("runtime.created");
      }

      async start() {
        const runtimeStartedAt = this.now();
        this.recordMetric("runtime.start");
        this.publishStatus(false, "starting");
        this.publishStatus(false, "fetchingManifest");
        this.manifest = this.descriptor.manifest || await this.fetchJSON(this.configuration.manifestPath);
        this.publishStatus(false, "loadingInitialBundles");
        await this.loadInitialBundles();
        this.primaryBundleID = this.selectPrimaryBundleID();
        this.primaryInstance = this.instances.get(this.primaryBundleID);
        this.publishStatus(false, "bootstrapping");
        const bootstrapStartedAt = this.now();
        this.recordMetric("bootstrap.start");
        this.bootstrapBundle(this.primaryBundleID, this.primaryInstance);
        this.updateSummary({
          bootstrapMs: this.durationSince(bootstrapStartedAt)
        });
        this.recordMetric("bootstrap.complete", {
          durationMs: this.durationSince(bootstrapStartedAt)
        });
        this.installEventListeners();
        this.installServerActionListeners();
        this.installNavigationListeners();
        this.installPresentationReconciler();
        this.publishStatus(true);
        this.completeReadyMetrics(runtimeStartedAt);
        this.scheduleAutomaticStages();
      }

      async fetchJSON(path) {
        const startedAt = this.now();
        this.recordMetric("manifest.fetch.start", { path });
        const response = await fetch(path, { credentials: "same-origin" });
        if (!response.ok) {
          throw new Error(`SwiftWeb manifest request failed with ${response.status}: ${path}`);
        }
        const text = await response.text();
        const byteLength = this.encodedLength(text);
        const durationMs = this.durationSince(startedAt);
        this.metrics.manifest = {
          path,
          status: response.status,
          byteLength,
          durationMs
        };
        this.updateSummary({
          manifestBytes: byteLength,
          manifestFetchMs: durationMs
        });
        this.recordMetric("manifest.fetch.complete", {
          path,
          status: response.status,
          byteLength,
          durationMs
        });
        return JSON.parse(text);
      }

      async loadInitialBundles() {
        const startedAt = this.now();
        this.recordMetric("bundles.initial.start");
        const before = new Set(this.loadedBundleIDs);
        const bundleIDs = this.initialBundleIDs();
        await this.loadBundles(bundleIDs);
        const loadedBundleIDs = Array.from(this.loadedBundleIDs).filter((bundleID) => !before.has(bundleID));
        const initialBytes = this.metrics.bundles
          .filter((bundle) => loadedBundleIDs.includes(bundle.bundleID))
          .reduce((total, bundle) => total + (bundle.byteLength || 0), 0);
        const durationMs = this.durationSince(startedAt);
        this.updateSummary({
          initialBundleIDs: loadedBundleIDs,
          initialBytes,
          initialLoadMs: durationMs
        });
        this.recordMetric("bundles.initial.complete", {
          bundleIDs: loadedBundleIDs,
          byteLength: initialBytes,
          durationMs
        });
      }

      initialBundleIDs() {
        const ids = new Set();
        if (this.manifest.runtimeBundleID) {
          ids.add(rawValue(this.manifest.runtimeBundleID));
        }
        for (const component of this.manifest.components || []) {
          if (component.loadPolicy === "eager") {
            ids.add(rawValue(component.bundleID));
          }
        }
        if (ids.size === 0 && this.manifest.bundles && this.manifest.bundles.length === 1) {
          ids.add(rawValue(this.manifest.bundles[0].id));
        }
        return Array.from(ids);
      }

      async scheduleAutomaticStages() {
        this.recordMetric("stages.schedule");
        this.scheduleVisibleBundles();
        this.scheduleInteractionBundles();
        this.scheduleIdleBundles();
      }

      scheduleVisibleBundles() {
        const components = this.componentsForPolicy("visible");
        if (components.length === 0) {
          return;
        }

        if (!("IntersectionObserver" in window)) {
          this.recordMetric("bundles.visible.fallbackToIdle", {
            componentCount: components.length
          });
          this.scheduleIdleLoad(
            components.map((component) => component.bundleID),
            "visible"
          );
          return;
        }

        const observer = new IntersectionObserver((entries) => {
          for (const entry of entries) {
            if (!entry.isIntersecting) {
              continue;
            }
            const componentID = entry.target.getAttribute("data-component");
            const component = components.find((record) => rawValue(record.componentID) === componentID);
            if (!component) {
              continue;
            }
            observer.unobserve(entry.target);
            this.recordMetric("bundles.visible.triggered", {
              componentID,
              bundleID: rawValue(component.bundleID)
            });
            this.loadBundles([component.bundleID]).catch((error) => {
              console.error("SwiftWeb visible WASM load failed", error);
            });
          }
        }, { rootMargin: "200px" });

        for (const component of components) {
          const element = this.componentElement(component);
          if (!element) {
            continue;
          }
          element.setAttribute("data-component", rawValue(component.componentID));
          observer.observe(element);
        }
      }

      scheduleInteractionBundles() {
        const components = this.componentsForPolicy("interaction");
        if (components.length === 0) {
          return;
        }

        const events = ["pointerover", "mouseover", "focusin", "touchstart", "pointerdown", "mousedown", "click"];
        const listener = (event) => {
          if (!(event.target instanceof Node)) {
            return;
          }
          for (const component of components) {
            const bundleID = rawValue(component.bundleID);
            if (this.loadedBundleIDs.has(bundleID)) {
              continue;
            }
            const element = this.componentElement(component);
            if (!element || !element.contains(event.target)) {
              continue;
            }
            this.recordMetric("bundles.interaction.triggered", {
              eventName: event.type,
              componentID: rawValue(component.componentID),
              bundleID
            });
            this.loadBundles([component.bundleID]).catch((error) => {
              console.error("SwiftWeb interaction WASM load failed", error);
            });
          }
        };

        for (const component of components) {
          const element = this.componentElement(component);
          if (element) {
            element.setAttribute("data-component", rawValue(component.componentID));
          }
        }

        for (const eventName of events) {
          document.addEventListener(eventName, listener, true);
        }
      }

      scheduleIdleBundles() {
        const components = this.componentsForPolicy("idle");
        if (components.length === 0) {
          return;
        }
        this.scheduleIdleLoad(
          components.map((component) => component.bundleID),
          "idle"
        );
      }

      scheduleIdleLoad(bundleIDs, policy) {
        const load = () => {
          this.recordMetric("bundles.idle.triggered", {
            policy,
            bundleIDs: bundleIDs.map((bundleID) => rawValue(bundleID))
          });
          this.loadBundles(bundleIDs).catch((error) => {
            console.error(`SwiftWeb ${policy} WASM load failed`, error);
          });
        };
        if ("requestIdleCallback" in window) {
          window.requestIdleCallback(load);
        } else {
          window.setTimeout(load, 0);
        }
      }

      componentsForPolicy(policy) {
        const seen = new Set();
        return (this.manifest.components || []).filter((component) => {
          if (component.loadPolicy !== policy) {
            return false;
          }
          const bundleID = rawValue(component.bundleID);
          if (!bundleID || this.loadedBundleIDs.has(bundleID)) {
            return false;
          }
          const key = `${rawValue(component.componentID)}|${bundleID}`;
          if (seen.has(key)) {
            return false;
          }
          seen.add(key);
          return true;
        });
      }

      componentElement(component) {
        const componentID = rawValue(component.componentID);
        const directElement = document.querySelector(`[data-component="${componentID}"]`);
        if (directElement instanceof Element) {
          return directElement;
        }

        const bundleID = rawValue(component.bundleID);
        const typeName = component.typeName || "";
        const typedElements = Array.from(document.querySelectorAll("[data-component-type]"));
        const typedBundleElement = typedElements.find((element) =>
          element.getAttribute("data-component-type") === typeName &&
          element.getAttribute("data-bundle") === bundleID
        );
        if (typedBundleElement instanceof Element) {
          return typedBundleElement;
        }

        const typedElement = typedElements.find((element) =>
          element.getAttribute("data-component-type") === typeName
        );
        if (typedElement instanceof Element) {
          return typedElement;
        }

        const componentRecord = (this.hydrationIndex?.components || []).find((record) => rawValue(record.id) === componentID);
        const nodeRecordValue = componentRecord ? nodeRecord(rawValue(componentRecord.nodeID), this) : null;
        const childID = nodeRecordValue && nodeRecordValue.childIDs && nodeRecordValue.childIDs.length > 0
          ? nodeRecordValue.childIDs[0]
          : componentRecord?.nodeID;
        const node = resolveDOMNode(childID, this);
        return node instanceof Element ? node : null;
      }

      async loadBundles(bundleIDs) {
        const ordered = this.dependencyClosure(bundleIDs);
        for (const bundleID of ordered) {
          await this.loadBundle(bundleID);
        }
      }

      dependencyClosure(bundleIDs) {
        const ordered = [];
        const visiting = new Set();
        const visited = new Set();

        const visit = (bundleID) => {
          if (visited.has(bundleID)) {
            return;
          }
          if (visiting.has(bundleID)) {
            throw new Error(`Cyclic SwiftWeb WASM bundle dependency at ${bundleID}`);
          }
          const bundle = this.bundle(bundleID);
          if (!bundle) {
            throw new Error(`Missing SwiftWeb WASM bundle ${bundleID}`);
          }
          visiting.add(bundleID);
          for (const dependency of bundle.dependencies || []) {
            visit(rawValue(dependency));
          }
          visiting.delete(bundleID);
          visited.add(bundleID);
          ordered.push(bundleID);
        };

        for (const bundleID of bundleIDs) {
          visit(rawValue(bundleID));
        }
        return ordered;
      }

      bundle(bundleID) {
        return (this.manifest.bundles || []).find((bundle) => rawValue(bundle.id) === bundleID) || null;
      }

      assetPathForBundleID(bundleID) {
        const bundle = this.bundle(bundleID);
        return bundle && bundle.asset && bundle.asset.path ? bundle.asset.path : "";
      }

      loadedBundleIDForAssetPath(assetPath, excludingBundleID = "") {
        if (!assetPath) {
          return "";
        }
        for (const loadedBundleID of this.loadedBundleIDs) {
          if (loadedBundleID === excludingBundleID) {
            continue;
          }
          if (this.assetPathForBundleID(loadedBundleID) === assetPath && this.instances.has(loadedBundleID)) {
            return loadedBundleID;
          }
        }
        return "";
      }

      loadingBundleIDForAssetPath(assetPath, excludingBundleID = "") {
        if (!assetPath) {
          return "";
        }
        for (const loadingBundleID of this.loading.keys()) {
          if (loadingBundleID === excludingBundleID) {
            continue;
          }
          if (this.assetPathForBundleID(loadingBundleID) === assetPath) {
            return loadingBundleID;
          }
        }
        return "";
      }

      bootstrappedBundleIDForAssetPath(assetPath, excludingBundleID = "") {
        if (!assetPath) {
          return "";
        }
        for (const bootstrappedBundleID of this.bootstrappedBundleIDs) {
          if (bootstrappedBundleID === excludingBundleID) {
            continue;
          }
          if (this.assetPathForBundleID(bootstrappedBundleID) === assetPath) {
            return bootstrappedBundleID;
          }
        }
        return "";
      }

      aliasLoadedBundle(rawBundleID, sourceBundleID, instance) {
        this.instances.set(rawBundleID, instance);
        const swiftRuntime = this.swiftRuntimes.get(sourceBundleID);
        if (swiftRuntime) {
          this.swiftRuntimes.set(rawBundleID, swiftRuntime);
        }
        if (this.bootstrappedBundleIDs.has(sourceBundleID)) {
          this.bootstrappedBundleIDs.add(rawBundleID);
        }
        this.loadedBundleIDs.add(rawBundleID);
        this.recordMetric("bundle.assetAliasHit", {
          bundleID: rawBundleID,
          sourceBundleID
        });
        this.publishStatus(this.metrics.ready === true, "bundleLoaded");
        this.publishMetrics();
        return instance;
      }

      async loadBundle(bundleID) {
        const rawBundleID = rawValue(bundleID);
        if (this.loadedBundleIDs.has(rawBundleID)) {
          this.recordMetric("bundle.cacheHit", { bundleID: rawBundleID });
          return this.instances.get(rawBundleID);
        }
        if (this.loading.has(rawBundleID)) {
          this.recordMetric("bundle.awaitExistingLoad", { bundleID: rawBundleID });
          return await this.loading.get(rawBundleID);
        }

        const assetPath = this.assetPathForBundleID(rawBundleID);
        const loadedAliasBundleID = this.loadedBundleIDForAssetPath(assetPath, rawBundleID);
        if (loadedAliasBundleID) {
          return this.aliasLoadedBundle(rawBundleID, loadedAliasBundleID, this.instances.get(loadedAliasBundleID));
        }
        const loadingAliasBundleID = this.loadingBundleIDForAssetPath(assetPath, rawBundleID);
        if (loadingAliasBundleID) {
          this.recordMetric("bundle.awaitAssetAliasLoad", {
            bundleID: rawBundleID,
            sourceBundleID: loadingAliasBundleID
          });
          const instance = await this.loading.get(loadingAliasBundleID);
          return this.aliasLoadedBundle(rawBundleID, loadingAliasBundleID, instance);
        }

        const runtimeWasReady = this.metrics.ready === true;
        this.publishStatus(runtimeWasReady, "instantiatingBundle", [rawBundleID]);
        const promise = this.instantiateBundle(rawBundleID);
        this.loading.set(rawBundleID, promise);
        try {
          const instance = await promise;
          this.instances.set(rawBundleID, instance);
          this.loadedBundleIDs.add(rawBundleID);
          this.publishStatus(runtimeWasReady, "bundleLoaded");
          this.publishMetrics();
          this.loading.delete(rawBundleID);
          return instance;
        } catch (error) {
          this.loading.delete(rawBundleID);
          throw error;
        }
      }

      async instantiateBundle(bundleID) {
        const bundle = this.bundle(bundleID);
        if (!bundle || !bundle.asset || !bundle.asset.path) {
          throw new Error(`SwiftWeb WASM bundle ${bundleID} has no asset path`);
        }

        const startedAt = this.now();
        const bundleMetrics = {
          bundleID,
          kind: bundle.kind || null,
          loadPolicy: bundle.loadPolicy || null,
          assetPath: bundle.asset.path,
          dependencies: (bundle.dependencies || []).map((dependency) => rawValue(dependency)),
          mode: this.metricsMode(),
          startedAt
        };

        try {
          this.recordMetric("bundle.instantiate.start", {
            bundleID,
            assetPath: bundle.asset.path
          });
          const javaScriptKitRuntimePath = this.configuration.javaScriptKitRuntimePath || "/__swiftweb/wasm/javascript-kit-runtime.js?v=1";
          const runtimeImportStartedAt = this.now();
          const { SwiftRuntime } = await swiftWebLoadJavaScriptKitRuntime(javaScriptKitRuntimePath);
          bundleMetrics.javaScriptKitRuntimePath = javaScriptKitRuntimePath;
          bundleMetrics.javaScriptKitImportMs = this.durationSince(runtimeImportStartedAt);

          const swiftRuntime = new SwiftRuntime();
          const wasi = new SwiftWebWASI();
          const imports = {
            bjs: swiftWebBridgeJSStubs(),
            javascript_kit: swiftRuntime.wasmImports,
            wasi_snapshot_preview1: wasi.imports
          };

          let instance;
          if (this.isDetailedMetrics()) {
            instance = await this.instantiateBundleDetailed(bundle, imports, bundleMetrics);
          } else {
            instance = await this.instantiateBundleStreaming(bundle, imports, bundleMetrics);
          }

          const bindStartedAt = this.now();
          wasi.bind(instance);
          swiftRuntime.setInstance(instance);
          bundleMetrics.bindMs = this.durationSince(bindStartedAt);

          const startStartedAt = this.now();
          if (typeof instance.exports._start === "function") {
            instance.exports._start();
          } else {
            swiftRuntime.main();
          }
          bundleMetrics.startMs = this.durationSince(startStartedAt);
          bundleMetrics.totalMs = this.durationSince(startedAt);
          this.swiftRuntimes.set(bundleID, swiftRuntime);
          this.recordBundleMetrics(bundleMetrics);
          this.recordMetric("bundle.instantiate.complete", {
            bundleID,
            byteLength: bundleMetrics.byteLength || null,
            durationMs: bundleMetrics.totalMs
          });
          return instance;
        } catch (error) {
          bundleMetrics.error = String(error && error.message ? error.message : error);
          bundleMetrics.totalMs = this.durationSince(startedAt);
          this.recordBundleMetrics(bundleMetrics);
          this.recordMetric("bundle.instantiate.failed", {
            bundleID,
            error: bundleMetrics.error,
            durationMs: bundleMetrics.totalMs
          });
          throw error;
        }
      }

      async instantiateBundleDetailed(bundle, imports, bundleMetrics) {
        const fetchStartedAt = this.now();
        const response = await fetch(bundle.asset.path, { credentials: "same-origin" });
        bundleMetrics.fetchStatus = response.status;
        if (!response.ok) {
          throw new Error(`SwiftWeb WASM bundle request failed with ${response.status}: ${bundle.asset.path}`);
        }
        const bytes = await response.arrayBuffer();
        bundleMetrics.byteLength = bytes.byteLength;
        bundleMetrics.downloadMs = this.durationSince(fetchStartedAt);

        const compileStartedAt = this.now();
        const module = await WebAssembly.compile(bytes);
        bundleMetrics.compileMs = this.durationSince(compileStartedAt);

        const instantiateStartedAt = this.now();
        const instance = await WebAssembly.instantiate(module, imports);
        bundleMetrics.instantiateMs = this.durationSince(instantiateStartedAt);
        return instance;
      }

      async instantiateBundleStreaming(bundle, imports, bundleMetrics) {
        const instantiateStartedAt = this.now();
        const response = await fetch(bundle.asset.path, { credentials: "same-origin" });
        bundleMetrics.fetchStatus = response.status;
        const contentLength = Number(response.headers.get("content-length") || 0);
        if (Number.isFinite(contentLength) && contentLength > 0) {
          bundleMetrics.byteLength = contentLength;
        }
        if (!response.ok) {
          throw new Error(`SwiftWeb WASM bundle request failed with ${response.status}: ${bundle.asset.path}`);
        }
        const result = await WebAssembly.instantiateStreaming(Promise.resolve(response), imports);
        bundleMetrics.streamingInstantiateMs = this.durationSince(instantiateStartedAt);
        return result.instance || result;
      }

      selectPrimaryBundleID() {
        if (this.manifest.runtimeBundleID) {
          const runtimeBundleID = rawValue(this.manifest.runtimeBundleID);
          if (this.instances.has(runtimeBundleID)) {
            return runtimeBundleID;
          }
        }
        for (const bundleID of this.instances.keys()) {
          return bundleID;
        }
        throw new Error("SwiftWeb WASM runtime bundle was not loaded");
      }

      bootstrapBundle(bundleID, instance, options = {}) {
        const rawBundleID = rawValue(bundleID);
        if (!options.force && this.bootstrappedBundleIDs.has(rawBundleID)) {
          this.recordMetric("bundle.bootstrap.cacheHit", { bundleID: rawBundleID });
          return null;
        }
        const assetPath = this.assetPathForBundleID(rawBundleID);
        const bootstrappedAliasBundleID = this.bootstrappedBundleIDForAssetPath(assetPath, rawBundleID);
        if (!options.force && bootstrappedAliasBundleID) {
          this.bootstrappedBundleIDs.add(rawBundleID);
          this.recordMetric("bundle.bootstrap.assetAliasHit", {
            bundleID: rawBundleID,
            sourceBundleID: bootstrappedAliasBundleID
          });
          return null;
        }
        if (!instance || typeof instance.exports.swiftweb_bootstrap !== "function") {
          throw new Error(`SwiftWeb WASM bundle ${rawBundleID} does not export swiftweb_bootstrap`);
        }

        const startedAt = this.now();
        const response = this.callRuntime("swiftweb_bootstrap", {
          hydrationIndex: this.hydrationIndex,
          documentNodeIDUpperBound: this.descriptor.documentNodeIDUpperBound ?? null,
          location: {
            href: window.location.href,
            search: window.location.search
          },
          mode: options.mode || undefined,
          actorBindings: this.descriptor.actorBindings || []
        }, instance);
        if (response && response.commandBatch && response.appliesDOMCommandsInRuntime !== true) {
          applyCommandBatch(response.commandBatch, this);
        }
        if (response && response.hydrationIndex) {
          this.hydrationIndex = response.hydrationIndex;
        }
        this.bootstrappedBundleIDs.add(rawBundleID);
        for (const loadedBundleID of this.loadedBundleIDs) {
          if (loadedBundleID !== rawBundleID && this.assetPathForBundleID(loadedBundleID) === assetPath) {
            this.bootstrappedBundleIDs.add(loadedBundleID);
          }
        }
        this.recordMetric("bundle.bootstrap.complete", {
          bundleID: rawBundleID,
          durationMs: this.durationSince(startedAt)
        });
        this.updateSummary({
          bootstrappedBundleIDs: Array.from(this.bootstrappedBundleIDs)
        });
        return response;
      }

      installEventListeners() {
        for (const eventName of swiftWebEventNames) {
          document.addEventListener(eventName, (event) => {
            const target = findEventTarget(event.target, eventName);
            if (!target) {
              return;
            }
            if (eventName === "submit") {
              event.preventDefault();
            }
            const handlerID = target.getAttribute(`${swiftWebRuntimeMarkers.eventAttributePrefix}${eventName}`);
            if (!handlerID) {
              return;
            }
            const payload = {
              handlerID: { rawValue: handlerID },
              event: domEventPayload(event),
              swiftWebComponentID: this.componentForEventTarget(target)?.componentID || null
            };
            if (isCoalescableInputEvent(eventName, event.target)) {
              this.enqueueCoalescedInputEvent(payload);
            } else {
              this.enqueueRuntimeEvent(payload);
            }
          }, true);
        }
      }

      enqueueRuntimeEvent(payload) {
        this.coalescedInputFlushScheduled = false;
        this.eventQueue = this.eventQueue.then(async () => {
          await this.dispatchPendingCoalescedInputEvents();
          await this.dispatchEvent(payload);
        }).catch((error) => {
          console.error("SwiftWeb WASM event dispatch failed", error);
        });
      }

      enqueueCoalescedInputEvent(payload) {
        const componentID = payload.swiftWebComponentID || "";
        const key = `${payload.handlerID.rawValue}:${componentID}`;
        this.coalescedInputEvents.set(key, payload);
        if (this.coalescedInputFlushActive || this.coalescedInputFlushScheduled) {
          return;
        }
        this.coalescedInputFlushScheduled = true;
        scheduleAnimationFrame(() => this.flushCoalescedInputEvents());
      }

      flushCoalescedInputEvents() {
        this.coalescedInputFlushScheduled = false;
        if (this.coalescedInputFlushActive || this.coalescedInputEvents.size === 0) {
          return;
        }
        this.coalescedInputFlushActive = true;
        this.eventQueue = this.eventQueue.then(async () => {
          await this.dispatchPendingCoalescedInputEvents();
        }).catch((error) => {
          console.error("SwiftWeb WASM coalesced input dispatch failed", error);
        }).finally(() => {
          this.coalescedInputFlushActive = false;
          if (this.coalescedInputEvents.size > 0 && !this.coalescedInputFlushScheduled) {
            this.coalescedInputFlushScheduled = true;
            scheduleAnimationFrame(() => this.flushCoalescedInputEvents());
          }
        });
      }

      async dispatchPendingCoalescedInputEvents() {
        if (this.coalescedInputEvents.size === 0) {
          return;
        }
        const payloads = Array.from(this.coalescedInputEvents.values());
        this.coalescedInputEvents.clear();
        for (const payload of payloads) {
          await this.dispatchEvent(payload);
        }
      }

      installServerActionListeners() {
        document.addEventListener("click", (event) => {
          const submitter = findServerActionSubmitter(event);
          const form = findServerActionForm(event, submitter);
          if (!form) {
            return;
          }
          event.preventDefault();
          event.stopPropagation();
          this.eventQueue = this.eventQueue.then(() => this.submitServerAction(form, { submitter })).catch((error) => {
            console.error("SwiftWeb server action failed", error);
          });
        }, true);

        document.addEventListener("submit", (event) => {
          const form = findServerActionForm(event, null);
          if (!form) {
            return;
          }
          event.preventDefault();
          event.stopPropagation();
          this.eventQueue = this.eventQueue.then(() => this.submitServerAction(form, event)).catch((error) => {
            console.error("SwiftWeb server action failed", error);
          });
        }, true);
      }

      installNavigationListeners() {
        document.addEventListener("click", (event) => {
          const anchor = navigationAnchorForEvent(event);
          if (!anchor) {
            return;
          }
          const target = new URL(anchor.getAttribute("href"), window.location.href);
          event.preventDefault();
          event.stopPropagation();
          this.eventQueue = this.eventQueue
            .then(() => this.navigateServerDocument(target.href, { history: "push" }))
            .catch((error) => {
              console.error("SwiftWeb navigation failed", error);
              window.location.assign(target.href);
            });
        }, true);

        window.addEventListener("popstate", () => {
          const target = new URL(window.location.href);
          if (this.isSameDocumentURL(target)) {
            this.currentDocumentURL = target.href;
            return;
          }
          this.eventQueue = this.eventQueue
            .then(() => this.navigateServerDocument(target.href, { history: "popstate" }))
            .catch((error) => {
              console.error("SwiftWeb history navigation failed", error);
              window.location.reload();
            });
        });
      }

      isSameDocumentURL(target) {
        const current = new URL(this.currentDocumentURL || window.location.href, window.location.href);
        return target.origin === current.origin &&
          target.pathname === current.pathname &&
          target.search === current.search;
      }

      // Upgrades server-rendered presentation dialogs to true top-layer modals.
      //
      // The server renders `<dialog data-presented>` with the `open` attribute
      // toggled by the binding. An `open` attribute alone yields a non-modal, in-flow
      // dialog (no top layer, no ::backdrop, no focus trap). This reconciler observes
      // the `data-presented` marker and the subtree, then drives the imperative
      // `showModal()` / `close()` lifecycle so the dialog is lifted to the browser top
      // layer. `close()` (not attribute removal) fires the native `close` event, which
      // the Swift-side handler uses to sync the binding back to `false`.
      installPresentationReconciler() {
        const reconcile = () => {
          const dialogs = document.querySelectorAll("dialog[data-presented]");
          for (const dialog of dialogs) {
            const shouldPresent = dialog.getAttribute("data-presented") === "true";
            const isModal = typeof dialog.matches === "function" && dialog.matches(":modal");
            if (shouldPresent && !isModal) {
              if (typeof dialog.showModal === "function") {
                // Drop the SSR `open` attribute first: showModal() throws if the
                // dialog is already open as a non-modal in-flow element.
                dialog.removeAttribute("open");
                try {
                  dialog.showModal();
                  this.bindPresentationLightDismiss(dialog);
                } catch (error) {
                  // Explicit, logged degradation — never a silent fallback. Keep the
                  // dialog visible in-flow via the `open` attribute so the binding
                  // still drives show/hide even when top-layer promotion fails.
                  console.warn("SwiftWeb presentation: showModal() failed, falling back to in-flow open", error);
                  dialog.setAttribute("open", "");
                }
              } else {
                console.warn("SwiftWeb presentation: <dialog>.showModal() unavailable, presenting in-flow only");
                dialog.setAttribute("open", "");
              }
            } else if (!shouldPresent && (isModal || dialog.open)) {
              // close() fires the native `close` event that syncs the binding.
              dialog.close();
            }
          }
        };
        reconcile();
        const observer = new MutationObserver(() => reconcile());
        observer.observe(document.documentElement, {
          attributes: true,
          attributeFilter: ["data-presented"],
          childList: true,
          subtree: true
        });
      }

      // Enforces a presentation dialog's interactive-dismissal policy across browsers.
      //
      // Browsers without native `closedby` support (Safari, Firefox) ignore the
      // attribute, so a modal <dialog> would light-dismiss on a backdrop tap or Esc
      // regardless of the declared policy. This restores the policy uniformly rather
      // than silently degrading:
      //   - "any": dismiss on a backdrop tap (Esc already dismisses natively).
      //   - "none": block Esc as well (interactiveDismissDisabled); the backdrop is
      //     never bound, so only the binding closes the dialog.
      //   - "closerequest": Esc dismisses natively; the backdrop is never bound.
      //
      // The content fills the dialog box via `.swui-presentation-surface`, so a click
      // whose target is the dialog element itself landed on the backdrop, not the
      // content. `close()` (not attribute removal) fires the native `close` event,
      // which the Swift-side handler uses to sync the binding back to `false`.
      bindPresentationLightDismiss(dialog) {
        if (dialog.__swuiDismissPolicyBound) {
          return;
        }
        dialog.__swuiDismissPolicyBound = true;
        const closedBy = dialog.getAttribute("closedby");
        if (closedBy === "none") {
          // A modal <dialog> still closes on Esc via the cancel event in browsers
          // that ignore `closedby`; preventing its default keeps the no-dismiss
          // guarantee uniform instead of degrading in Safari and Firefox.
          dialog.addEventListener("cancel", (event) => {
            event.preventDefault();
          });
          return;
        }
        if (closedBy !== "any") {
          return;
        }
        dialog.addEventListener("click", (event) => {
          if (event.target === dialog) {
            dialog.close();
          }
        });
      }

      async submitServerAction(form, event) {
        const startedAt = this.now();
        const method = (form.getAttribute("method") || "post").toUpperCase();
        const action = form.getAttribute("action") || window.location.href;
        const url = new URL(action, window.location.href);
        const body = new FormData(form);
        if (event.submitter && event.submitter.name) {
          body.set(event.submitter.name, event.submitter.value || "");
        }
        if (method === "GET") {
          appendFormDataToURL(body, url);
        }
        const response = await fetch(url.href, {
          method,
          body: method === "GET" ? null : body,
          credentials: "same-origin",
          headers: {
            "Accept": "application/json, text/html;q=0.9",
            "X-SwiftWeb-Action-Mode": "client",
            ...this.csrfHeaders()
          }
        });
        await this.handleServerActionResponse(response);
        this.recordMetric("serverAction.submit.complete", {
          action: url.pathname,
          durationMs: this.durationSince(startedAt)
        });
        this.publishMetrics();
      }

      async handleServerActionResponse(response) {
        const contentType = response.headers.get("content-type") || "";
        if (!response.ok) {
          throw new Error(`SwiftWeb server action request failed with ${response.status}`);
        }
        if (contentType.includes("application/json")) {
          const result = await response.json();
          await this.applyActionResult(result);
          return;
        }
        if (contentType.includes("text/html")) {
          const html = await response.text();
          this.mergeServerDocument(html);
          return;
        }
      }

      async applyActionResult(result) {
        if (!result || !result.kind) {
          return;
        }
        switch (result.kind) {
          case "redirect":
            window.location.assign(result.body || "/");
            return;
          case "invalidate":
            await this.invalidateServerDocument(result.body || window.location.href);
            return;
          case "html":
            if (result.body) {
              this.mergeServerDocument(result.body);
            }
            return;
          case "empty":
          case "json":
          case "text":
            return;
          default:
            throw new Error(`Unsupported SwiftWeb action result: ${result.kind}`);
        }
      }

      async invalidateServerDocument(path) {
        const target = new URL(path || window.location.href, window.location.href);
        const response = await fetch(target.href, {
          credentials: "same-origin",
          headers: {
            "Accept": "text/html",
            "X-SwiftWeb-Invalidation": "page",
            ...this.csrfHeaders()
          }
        });
        if (!response.ok) {
          throw new Error(`SwiftWeb page invalidation failed with ${response.status}: ${target.pathname}`);
        }
        const html = await response.text();
        this.mergeServerDocument(html);
      }

      async navigateServerDocument(href, options = {}) {
        const target = new URL(href || window.location.href, window.location.href);
        const startedAt = this.now();
        const historyMode = options.history || "push";
        this.recordMetric("navigation.start", {
          href: target.href,
          history: historyMode
        });
        this.publishStatus(false, "navigating");
        this.publishMetrics();

        let response;
        const fetchStartedAt = this.now();
        try {
          response = await fetch(target.href, {
            credentials: "same-origin",
            headers: {
              "Accept": "text/html",
              "X-SwiftWeb-Navigation": "client",
              ...this.csrfHeaders()
            }
          });
        } catch (error) {
          this.recordMetric("navigation.fetch.failed", {
            href: target.href,
            error: String(error && error.message ? error.message : error)
          });
          throw error;
        }

        const finalURL = new URL(response.url || target.href, window.location.href);
        if (finalURL.origin !== window.location.origin) {
          this.recordMetric("navigation.fallback.crossOriginRedirect", { href: finalURL.href });
          window.location.assign(finalURL.href);
          return;
        }
        const contentType = response.headers.get("content-type") || "";
        if (!response.ok || !contentType.includes("text/html")) {
          this.recordMetric("navigation.fallback.native", {
            href: finalURL.href,
            status: response.status,
            contentType
          });
          window.location.assign(finalURL.href);
          return;
        }

        const html = await response.text();
        this.recordMetric("navigation.fetch.complete", {
          href: finalURL.href,
          history: historyMode,
          status: response.status,
          contentType,
          byteLength: this.encodedLength(html),
          durationMs: this.durationSince(fetchStartedAt)
        });
        this.publishMetrics();
        if (historyMode === "push" && finalURL.href !== window.location.href) {
          window.history.pushState({ swiftWeb: true }, "", finalURL.href);
          this.recordMetric("navigation.history.updated", {
            href: finalURL.href,
            history: "push"
          });
        } else if (historyMode === "replace" && finalURL.href !== window.location.href) {
          window.history.replaceState({ swiftWeb: true }, "", finalURL.href);
          this.recordMetric("navigation.history.updated", {
            href: finalURL.href,
            history: "replace"
          });
        }
        this.currentDocumentURL = finalURL.href;
        this.mergeServerDocument(html, {
          mode: "navigation",
          preserveClientNodes: false,
          updateTitle: true
        });
        await this.rebootstrapServerDocument("navigation");
        this.publishStatus(true);
        this.recordMetric("navigation.complete", {
          href: finalURL.href,
          history: historyMode,
          durationMs: this.durationSince(startedAt)
        });
        this.publishMetrics();
      }

      async rebootstrapServerDocument(mode) {
        const startedAt = this.now();
        if (this.documentHydrationIndex) {
          this.hydrationIndex = this.documentHydrationIndex;
        }
        if (!this.manifest && this.configuration && this.configuration.manifestPath) {
          this.manifest = await this.fetchJSON(this.configuration.manifestPath);
        }
        const bundleIDs = this.initialBundleIDs();
        await this.loadBundles(bundleIDs);
        this.primaryBundleID = this.selectPrimaryBundleID();
        this.primaryInstance = this.instances.get(this.primaryBundleID);
        this.bootstrappedBundleIDs.clear();
        const bootstrappedBundleIDs = [];
        for (const bundleID of bundleIDs) {
          const rawBundleID = rawValue(bundleID);
          const instance = this.instances.get(rawBundleID);
          if (!instance) {
            continue;
          }
          this.bootstrapBundle(rawBundleID, instance, {
            force: true,
            mode
          });
          bootstrappedBundleIDs.push(rawBundleID);
        }
        this.updateSummary({
          navigationBootstrappedBundleIDs: bootstrappedBundleIDs
        });
        this.recordMetric("navigation.rebootstrap.complete", {
          mode,
          bundleIDs: bootstrappedBundleIDs,
          durationMs: this.durationSince(startedAt)
        });
        this.publishMetrics();
      }

      mergeServerDocument(html, options = {}) {
        const nextDocument = new DOMParser().parseFromString(html, "text/html");
        if (options.updateTitle && nextDocument.title) {
          document.title = nextDocument.title;
        }
        this.mergeHeadStyle(nextDocument, "swui-base");
        this.mergeHeadStyle(nextDocument, "swui-atomic");
        if (options.preserveClientNodes === false) {
          const replaced = this.replaceServerDocumentBody(nextDocument);
          this.updateDescriptorFromDocument(nextDocument);
          this.recordMetric("serverDocument.merge.complete", {
            mode: options.mode || "navigation",
            strategy: "body",
            replacementCount: replaced ? 1 : 0,
            replacedNodeIDs: []
          });
          return;
        }
        const protectedNodeIDs = this.protectedClientNodeIDs();
        const currentNodes = Array.from(document.querySelectorAll(`[${swiftWebRuntimeMarkers.nodeAttribute}]`));
        const replacedNodeIDs = [];
        let replacementCount = 0;
        for (const current of currentNodes) {
          if (!current.isConnected) {
            continue;
          }
          if (isDocumentShellElement(current)) {
            continue;
          }
          const nodeID = current.getAttribute(swiftWebRuntimeMarkers.nodeAttribute);
          if (!nodeID || protectedNodeIDs.has(nodeID) || containsProtectedSwiftNode(current, protectedNodeIDs)) {
            continue;
          }
          const next = nextDocument.querySelector(`[${swiftWebRuntimeMarkers.nodeAttribute}="${nodeID}"]`);
          if (!next || next.tagName !== current.tagName) {
            continue;
          }
          if (current.outerHTML === next.outerHTML) {
            continue;
          }
          copyElementAttributes(current, next);
          current.innerHTML = next.innerHTML;
          replacedNodeIDs.push(nodeID);
          replacementCount += 1;
        }
        this.updateDescriptorFromDocument(nextDocument);
        this.recordMetric("serverDocument.merge.complete", {
          mode: options.mode || "invalidation",
          strategy: "node",
          replacementCount,
          replacedNodeIDs
        });
      }

      replaceServerDocumentBody(nextDocument) {
        if (!nextDocument.body || !document.body) {
          this.recordMetric("serverDocument.body.replace.skipped", {
            reason: "missing body"
          });
          return false;
        }
        const childCount = nextDocument.body.childNodes.length;
        copyElementAttributes(document.body, nextDocument.body);
        const nextChildren = Array.from(nextDocument.body.childNodes)
          .map((node) => document.importNode(node, true));
        document.body.replaceChildren(...nextChildren);
        this.recordMetric("serverDocument.body.replace", {
          childCount,
          bodyClass: document.body.getAttribute("class") || ""
        });
        this.publishMetrics();
        return true;
      }

      mergeHeadStyle(nextDocument, id) {
        const next = nextDocument.getElementById(id);
        if (!next || !next.textContent) {
          return;
        }
        const current = document.getElementById(id);
        if (!current) {
          document.head.appendChild(document.importNode(next, true));
          return;
        }
        if (!current.textContent.includes(next.textContent)) {
          current.textContent += next.textContent;
        }
      }

      csrfHeaders() {
        if (!this.security || !this.security.csrfToken) {
          return {};
        }
        const headerName = this.security.csrfHeaderName || "X-CSRF-Token";
        return { [headerName]: this.security.csrfToken };
      }

      protectedClientNodeIDs() {
        const hydrationIndex = this.documentHydrationIndex || this.hydrationIndex;
        const protectedNodeIDs = new Set();
        const knownBoundaries = new Set(
          (this.manifest?.components || []).map((component) =>
            `${component.typeName || ""}|${rawValue(component.bundleID)}`
          )
        );
        for (const element of document.querySelectorAll(`[data-hmr-boundary='true'][${swiftWebRuntimeMarkers.nodeAttribute}]`)) {
          const typeName = element.getAttribute("data-component-type") || "";
          const bundleID = element.getAttribute("data-bundle") || "";
          if (knownBoundaries.size > 0 && !knownBoundaries.has(`${typeName}|${bundleID}`)) {
            continue;
          }
          addSwiftDOMSubtree(element, protectedNodeIDs);
        }
        const clientComponentIDs = new Set(
          (this.manifest?.components || []).map((component) => rawValue(component.componentID))
        );
        for (const component of hydrationIndex?.components || []) {
          if (clientComponentIDs.has(rawValue(component.id))) {
            addSwiftNodeSubtree(rawValue(component.nodeID), protectedNodeIDs, this, hydrationIndex);
          }
        }
        return protectedNodeIDs;
      }

      updateDescriptorFromDocument(nextDocument) {
        const currentDescriptorElement = document.getElementById("client-runtime");
        const nextDescriptorElement = nextDocument.getElementById("client-runtime");
        if (!currentDescriptorElement || !nextDescriptorElement || !nextDescriptorElement.textContent) {
          return;
        }
        currentDescriptorElement.textContent = nextDescriptorElement.textContent;
        const descriptor = JSON.parse(nextDescriptorElement.textContent);
        this.descriptor = descriptor;
        this.configuration = descriptor.wasm || this.configuration;
        this.security = descriptor.security || {};
        if (descriptor.hydrationIndex) {
          this.documentHydrationIndex = descriptor.hydrationIndex;
        }
        if (descriptor.manifest) {
          this.manifest = descriptor.manifest;
        }
      }

      publishStatus(ready, phase = ready ? "ready" : "loading", loadingBundleIDs = []) {
        document.documentElement.setAttribute("data-wasm-ready", ready ? "true" : "false");
        document.documentElement.setAttribute("data-wasm-phase", phase);
        document.documentElement.setAttribute("data-wasm-loaded", Array.from(this.loadedBundleIDs).join(","));
        const status = {
          ready,
          phase,
          loadingBundleIDs,
          loadedBundleIDs: Array.from(this.loadedBundleIDs)
        };
        window.__swiftWebWasmRuntimeStatus = status;
        window.dispatchEvent(new CustomEvent("wasmStatus", { detail: status }));
        if (this.metrics) {
          this.metrics.ready = ready;
          this.metrics.phase = phase;
          this.metrics.loadedBundleIDs = Array.from(this.loadedBundleIDs);
        }
      }

      async dispatchEvent(payload) {
        const startedAt = this.now();
        const componentID = payload.swiftWebComponentID || this.componentIDForHandler(payload.handlerID.rawValue);
        let targetInstance = this.primaryInstance;
        if (componentID) {
          targetInstance = await this.instanceForComponent(componentID);
        }
        const runtimePayload = {
          handlerID: payload.handlerID,
          event: payload.event,
          componentID: componentID ? { rawValue: componentID } : null
        };
        const response = this.callRuntime("swiftweb_dispatch_event", runtimePayload, targetInstance);
        if (response && response.commandBatch && response.appliesDOMCommandsInRuntime !== true) {
          applyCommandBatch(response.commandBatch, this);
        }
        if (response && response.hydrationIndex) {
          this.hydrationIndex = response.hydrationIndex;
        }
        const durationMs = this.durationSince(startedAt);
        const dispatchMetrics = {
          handlerID: payload.handlerID.rawValue,
          componentID,
          durationMs,
          commandCount: response && response.commandBatch && Array.isArray(response.commandBatch.commands)
            ? response.commandBatch.commands.length
            : 0,
          appliesDOMCommandsInRuntime: response ? response.appliesDOMCommandsInRuntime === true : false
        };
        if (this.isMetricsEnabled()) {
          this.metrics.eventDispatches.push(dispatchMetrics);
          this.updateSummary({
            eventDispatchCount: this.metrics.eventDispatches.length,
            lastEventDispatchMs: durationMs
          });
        }
        this.recordMetric("event.dispatch.complete", dispatchMetrics);
        this.publishMetrics();
      }

      async instanceForComponent(componentID) {
        const component = (this.manifest.components || []).find((record) => rawValue(record.componentID) === componentID);
        if (!component) {
          return this.primaryInstance;
        }
        await this.loadBundles([component.bundleID]);
        const bundleID = rawValue(component.bundleID);
        const instance = this.instances.get(bundleID);
        if (instance && typeof instance.exports.swiftweb_dispatch_event === "function") {
          this.bootstrapBundle(bundleID, instance);
          return instance;
        }
        return this.primaryInstance;
      }

      componentForEventTarget(target) {
        if (!(target instanceof Element)) {
          return null;
        }
        const boundary = target.closest("[data-component-type][data-bundle]");
        if (boundary) {
          const typeName = boundary.getAttribute("data-component-type") || "";
          const bundleID = boundary.getAttribute("data-bundle") || "";
          const component = (this.manifest.components || []).find((record) =>
            record.typeName === typeName && rawValue(record.bundleID) === bundleID
          );
          if (component) {
            return {
              componentID: rawValue(component.componentID),
              bundleID: rawValue(component.bundleID),
              typeName: component.typeName
            };
          }
        }

        const componentElement = target.closest("[data-component]");
        const componentID = componentElement ? componentElement.getAttribute("data-component") : null;
        const component = (this.manifest.components || []).find((record) => rawValue(record.componentID) === componentID);
        if (!component) {
          return null;
        }
        return {
          componentID: rawValue(component.componentID),
          bundleID: rawValue(component.bundleID),
          typeName: component.typeName
        };
      }

      cacheBustedAssetPath(assetPath, contentHash) {
        if (!assetPath || !contentHash) {
          return assetPath;
        }
        const url = new URL(assetPath, window.location.href);
        url.searchParams.set("swiftweb-hmr", contentHash);
        return `${url.pathname}${url.search}${url.hash}`;
      }

      async applyHotUpdate(update) {
        if (!update || !update.bundleID || !update.assetPath) {
          throw new Error("SwiftWeb HMR client component update is missing bundle metadata");
        }

        const bundleID = rawValue(update.bundleID);
        const assetPath = this.cacheBustedAssetPath(update.assetPath, update.contentHash);
        let bundle = this.bundle(bundleID);
        const previousBundles = Array.isArray(this.manifest.bundles) ? [...this.manifest.bundles] : [];
        const hadBundle = !!bundle;
        const previousAsset = bundle && bundle.asset ? { ...bundle.asset } : null;
        const previousInstance = this.instances.get(bundleID) || null;
        const previousSwiftRuntime = this.swiftRuntimes.get(bundleID) || null;
        const previousLoaded = this.loadedBundleIDs.has(bundleID);
        const previousBootstrapped = this.bootstrappedBundleIDs.has(bundleID);
        const previousLoading = this.loading.get(bundleID) || null;
        const hadLoading = this.loading.has(bundleID);

        try {
          if (!bundle) {
            bundle = {
              id: { rawValue: bundleID },
              kind: "component",
              asset: { path: assetPath },
              symbols: [],
              dependencies: [],
              components: [],
              loadPolicy: "eager",
              estimatedByteSize: 0
            };
            this.manifest.bundles = [...(this.manifest.bundles || []), bundle];
          } else {
            bundle.asset = { ...(bundle.asset || {}), path: assetPath };
          }

          const stateSnapshot = previousInstance ? this.snapshotState(previousInstance) : null;

          this.instances.delete(bundleID);
          this.swiftRuntimes.delete(bundleID);
          this.loadedBundleIDs.delete(bundleID);
          this.bootstrappedBundleIDs.delete(bundleID);
          this.loading.delete(bundleID);

          this.recordMetric("hmr.clientComponent.start", {
            bundleID,
            componentTypeName: update.componentTypeName || null,
            contentHash: update.contentHash || null
          });
          const instance = await this.loadBundle(bundleID);
          const response = this.callRuntime("swiftweb_bootstrap", {
            hydrationIndex: this.hydrationIndex,
            documentNodeIDUpperBound: this.descriptor.documentNodeIDUpperBound ?? null,
            location: {
              href: window.location.href,
              search: window.location.search
            },
            mode: "hotReload",
            stateSnapshot,
            actorBindings: this.descriptor.actorBindings || []
          }, instance);
          if (response && response.hydrationIndex) {
            this.updateComponentSchemasFromHydrationIndex(response.hydrationIndex, bundleID, update);
          }
          if (response && response.commandBatch && response.appliesDOMCommandsInRuntime !== true) {
            applyCommandBatch(response.commandBatch, this);
          }
          if (response && response.hydrationIndex) {
            this.hydrationIndex = response.hydrationIndex;
          }
          this.bootstrappedBundleIDs.add(bundleID);
          this.recordMetric("hmr.clientComponent.complete", {
            bundleID,
            commandCount: response && response.commandBatch && Array.isArray(response.commandBatch.commands)
              ? response.commandBatch.commands.length
              : 0
          });
          this.publishMetrics();
          return response;
        } catch (error) {
          this.manifest.bundles = previousBundles;
          if (hadBundle) {
            const restoredBundle = this.bundle(bundleID);
            if (restoredBundle) {
              restoredBundle.asset = previousAsset ? { ...previousAsset } : previousAsset;
            }
          }
          if (previousInstance) {
            this.instances.set(bundleID, previousInstance);
          } else {
            this.instances.delete(bundleID);
          }
          if (previousSwiftRuntime) {
            this.swiftRuntimes.set(bundleID, previousSwiftRuntime);
          } else {
            this.swiftRuntimes.delete(bundleID);
          }
          if (previousLoaded) {
            this.loadedBundleIDs.add(bundleID);
          } else {
            this.loadedBundleIDs.delete(bundleID);
          }
          if (previousBootstrapped) {
            this.bootstrappedBundleIDs.add(bundleID);
          } else {
            this.bootstrappedBundleIDs.delete(bundleID);
          }
          if (hadLoading) {
            this.loading.set(bundleID, previousLoading);
          } else {
            this.loading.delete(bundleID);
          }
          this.recordMetric("hmr.clientComponent.failed", {
            bundleID,
            error: String(error && error.message ? error.message : error)
          });
          throw error;
        }
      }

      snapshotState(instance) {
        if (!instance || !instance.exports || typeof instance.exports.swiftweb_snapshot_state !== "function") {
          return null;
        }
        return this.callRuntimeNoInput("swiftweb_snapshot_state", instance);
      }

      updateComponentSchemasFromHydrationIndex(hydrationIndex, bundleID, update) {
        if (!hydrationIndex || !Array.isArray(hydrationIndex.components) || !Array.isArray(this.manifest?.components)) {
          return;
        }
        const hydratedByID = new Map();
        for (const component of hydrationIndex.components) {
          hydratedByID.set(rawValue(component.id), component);
        }
        for (const component of this.manifest.components) {
          const componentBundleID = rawValue(component.bundleID);
          const componentID = rawValue(component.componentID);
          const componentTypeName = component.typeName || "";
          const matchesBundle = componentBundleID === bundleID;
          const matchesType = update && update.componentTypeName && componentTypeName.endsWith(update.componentTypeName);
          if (!matchesBundle && !matchesType) {
            continue;
          }
          const hydrated = hydratedByID.get(componentID)
            || hydrationIndex.components.find((record) => record.typeName === componentTypeName || componentTypeName.endsWith(record.typeName));
          if (!hydrated) {
            continue;
          }
          component.stateSchemaHash = stateSchemaHash(hydrated.stateSlots || []);
          component.environmentSchemaHash = environmentSchemaHash(hydrated.environmentSnapshot || { values: [] });
        }
      }

      componentIDForHandler(handlerID) {
        const hydrationIndex = this.documentHydrationIndex || this.hydrationIndex;
        const binding = (hydrationIndex?.handlers || []).find((handler) => rawValue(handler.handlerID) === handlerID);
        return binding && binding.componentID ? rawValue(binding.componentID) : null;
      }

      callRuntime(exportName, payload, instance = this.primaryInstance) {
        const exports = instance.exports;
        const fn = exports[exportName];
        if (typeof fn !== "function") {
          throw new Error(`SwiftWeb WASM export ${exportName} was not found`);
        }

        const bytes = new TextEncoder().encode(JSON.stringify(payload));
        const pointer = exports.swiftweb_alloc(bytes.length);
        new Uint8Array(exports.memory.buffer, pointer, bytes.length).set(bytes);
        const status = fn(pointer, bytes.length);
        exports.swiftweb_dealloc(pointer, bytes.length);
        const response = this.readResponse(exports);
        if (status !== 0) {
          throw new Error(response && response.error ? response.error : `SwiftWeb WASM call failed: ${exportName}`);
        }
        return response;
      }

      callRuntimeNoInput(exportName, instance = this.primaryInstance) {
        const exports = instance.exports;
        const fn = exports[exportName];
        if (typeof fn !== "function") {
          throw new Error(`SwiftWeb WASM export ${exportName} was not found`);
        }

        const status = fn();
        const response = this.readResponse(exports);
        if (status !== 0) {
          throw new Error(response && response.error ? response.error : `SwiftWeb WASM call failed: ${exportName}`);
        }
        return response;
      }

      readResponse(exports) {
        const pointer = exports.swiftweb_response_ptr();
        const length = exports.swiftweb_response_len();
        if (!pointer || !length) {
          return null;
        }
        const bytes = new Uint8Array(exports.memory.buffer, pointer, length);
        const text = new TextDecoder().decode(bytes);
        exports.swiftweb_response_free();
        return JSON.parse(text);
      }

      createMetrics() {
        return {
          version: 1,
          mode: this.metricsMode(),
          startedAt: this.now(),
          ready: false,
          phase: "created",
          manifest: null,
          loadedBundleIDs: [],
          bundles: [],
          eventDispatches: [],
          events: [],
          summary: {}
        };
      }

      metricsMode() {
        return this.configuration && this.configuration.metricsMode
          ? this.configuration.metricsMode
          : "summary";
      }

      isMetricsEnabled() {
        return this.metricsMode() !== "disabled";
      }

      isDetailedMetrics() {
        return this.metricsMode() === "detailed";
      }

      now() {
        if (typeof performance !== "undefined" && typeof performance.now === "function") {
          return performance.now();
        }
        return Date.now();
      }

      durationSince(startedAt) {
        return this.roundMetric(this.now() - startedAt);
      }

      roundMetric(value) {
        return Math.round(value * 100) / 100;
      }

      encodedLength(text) {
        if (typeof TextEncoder !== "undefined") {
          return new TextEncoder().encode(text).length;
        }
        return text.length;
      }

      recordMetric(name, detail = {}) {
        if (!this.isMetricsEnabled()) {
          return null;
        }
        const event = {
          name,
          at: this.roundMetric(this.now()),
          ...detail
        };
        this.metrics.events.push(event);
        return event.at;
      }

      recordBundleMetrics(bundleMetrics) {
        if (!this.isMetricsEnabled()) {
          return;
        }
        const existingIndex = this.metrics.bundles.findIndex((bundle) => bundle.bundleID === bundleMetrics.bundleID);
        if (existingIndex >= 0) {
          this.metrics.bundles[existingIndex] = bundleMetrics;
        } else {
          this.metrics.bundles.push(bundleMetrics);
        }
        this.updateSummary(this.bundleSummary());
      }

      bundleSummary() {
        const bundles = this.metrics.bundles;
        return {
          bundleCount: bundles.length,
          totalWasmBytes: bundles.reduce((total, bundle) => total + (bundle.byteLength || 0), 0),
          javaScriptKitImportMs: this.sumMetric(bundles, "javaScriptKitImportMs"),
          wasmDownloadMs: this.sumMetric(bundles, "downloadMs"),
          wasmCompileMs: this.sumMetric(bundles, "compileMs"),
          wasmInstantiateMs: this.sumMetric(bundles, "instantiateMs"),
          wasmStreamingInstantiateMs: this.sumMetric(bundles, "streamingInstantiateMs"),
          wasmStartMs: this.sumMetric(bundles, "startMs")
        };
      }

      sumMetric(records, key) {
        return this.roundMetric(records.reduce((total, record) => total + (record[key] || 0), 0));
      }

      updateSummary(partial) {
        if (!this.isMetricsEnabled()) {
          return;
        }
        this.metrics.summary = {
          ...this.metrics.summary,
          ...partial
        };
      }

      completeReadyMetrics(startedAt) {
        if (!this.isMetricsEnabled()) {
          return;
        }
        this.updateSummary({
          readyMs: this.durationSince(startedAt),
          loadedBundleIDs: Array.from(this.loadedBundleIDs)
        });
        this.recordMetric("runtime.ready", {
          durationMs: this.metrics.summary.readyMs,
          loadedBundleIDs: Array.from(this.loadedBundleIDs)
        });
        this.publishMetrics();
      }

      recordFailure(error) {
        if (!this.isMetricsEnabled()) {
          return;
        }
        const message = String(error && error.message ? error.message : error);
        this.metrics.ready = false;
        this.metrics.phase = "failed";
        this.metrics.error = message;
        this.recordMetric("runtime.failed", { error: message });
        this.publishMetrics();
      }

      publishMetrics() {
        if (!this.isMetricsEnabled()) {
          return;
        }
        window.__swiftWebWasmRuntimeMetrics = this.metrics;
        if (!document.documentElement) {
          return;
        }
        document.documentElement.setAttribute("data-wasm-metrics-mode", this.metrics.mode);
        document.documentElement.setAttribute("data-wasm-metrics-version", String(this.metrics.version));
        this.setMetricAttribute("ready-ms", this.metrics.summary.readyMs);
        this.setMetricAttribute("initial-bytes", this.metrics.summary.initialBytes);
        this.setMetricAttribute("total-wasm-bytes", this.metrics.summary.totalWasmBytes);
        this.setMetricAttribute("manifest-fetch-ms", this.metrics.summary.manifestFetchMs);
        this.setMetricAttribute("javascript-kit-import-ms", this.metrics.summary.javaScriptKitImportMs);
        this.setMetricAttribute("wasm-download-ms", this.metrics.summary.wasmDownloadMs);
        this.setMetricAttribute("wasm-compile-ms", this.metrics.summary.wasmCompileMs);
        this.setMetricAttribute("wasm-instantiate-ms", this.metrics.summary.wasmInstantiateMs);
        this.setMetricAttribute("wasm-streaming-instantiate-ms", this.metrics.summary.wasmStreamingInstantiateMs);
        this.setMetricAttribute("wasm-start-ms", this.metrics.summary.wasmStartMs);
        this.setMetricAttribute("event-dispatch-count", this.metrics.summary.eventDispatchCount);
        this.publishMetricsElement();
        this.publishRuntimeLogPanels();
      }

      setMetricAttribute(name, value) {
        if (value === null || value === undefined || Number.isNaN(Number(value))) {
          return;
        }
        document.documentElement.setAttribute(`data-wasm-${name}`, String(value));
      }

      publishMetricsElement() {
        let element = document.getElementById("wasm-runtime-metrics");
        if (!element) {
          element = document.createElement("script");
          element.type = "application/json";
          element.id = "wasm-runtime-metrics";
          const parent = document.head || document.body || document.documentElement;
          parent.appendChild(element);
        }
        element.textContent = JSON.stringify(this.metrics);
      }

      publishRuntimeLogPanels() {
        const summaryElements = Array.from(document.querySelectorAll("[data-swiftweb-runtime-summary]"));
        const logElements = Array.from(document.querySelectorAll("[data-swiftweb-runtime-log]"));
        if (summaryElements.length === 0 && logElements.length === 0) {
          return;
        }

        const summaryText = this.runtimeSummaryText();
        const logText = this.runtimeLogText();
        for (const element of summaryElements) {
          element.textContent = summaryText;
        }
        for (const element of logElements) {
          element.textContent = logText;
        }
      }

      runtimeSummaryText() {
        const summary = this.metrics.summary || {};
        const parts = [
          `phase=${this.metrics.phase}`,
          `ready=${this.metrics.ready ? "true" : "false"}`
        ];
        if (summary.readyMs !== undefined) {
          parts.push(`ready=${summary.readyMs}ms`);
        }
        if (summary.totalWasmBytes !== undefined) {
          parts.push(`wasm=${this.formatBytes(summary.totalWasmBytes)}`);
        }
        if (summary.wasmDownloadMs !== undefined) {
          parts.push(`download=${summary.wasmDownloadMs}ms`);
        }
        if (summary.wasmInstantiateMs !== undefined) {
          parts.push(`instantiate=${summary.wasmInstantiateMs}ms`);
        }
        if (summary.navigationBootstrappedBundleIDs) {
          parts.push(`bootstrapped=${summary.navigationBootstrappedBundleIDs.join(",")}`);
        }
        return parts.join("\n");
      }

      runtimeLogText() {
        const events = Array.isArray(this.metrics.events) ? this.metrics.events : [];
        if (events.length === 0) {
          return "No runtime events recorded";
        }
        return events
          .slice(-18)
          .map((event) => this.runtimeLogLine(event))
          .join("\n");
      }

      runtimeLogLine(event) {
        const fields = [`${event.at}ms`, event.name];
        if (event.href) {
          fields.push(this.pathFromHref(event.href));
        }
        if (event.history) {
          fields.push(`history=${event.history}`);
        }
        if (event.strategy) {
          fields.push(`strategy=${event.strategy}`);
        }
        if (event.status !== undefined) {
          fields.push(`status=${event.status}`);
        }
        if (event.byteLength !== undefined) {
          fields.push(`bytes=${this.formatBytes(event.byteLength)}`);
        }
        if (event.replacementCount !== undefined) {
          fields.push(`replacements=${event.replacementCount}`);
        }
        if (event.childCount !== undefined) {
          fields.push(`children=${event.childCount}`);
        }
        if (event.bundleIDs) {
          fields.push(`bundles=${event.bundleIDs.join(",")}`);
        }
        if (event.durationMs !== undefined) {
          fields.push(`duration=${event.durationMs}ms`);
        }
        if (event.error) {
          fields.push(`error=${event.error}`);
        }
        return fields.join(" | ");
      }

      pathFromHref(href) {
        try {
          return new URL(href, window.location.href).pathname;
        } catch {
          return String(href);
        }
      }

      formatBytes(value) {
        const bytes = Number(value) || 0;
        if (bytes >= 1024 * 1024) {
          return `${this.roundMetric(bytes / (1024 * 1024))}MB`;
        }
        if (bytes >= 1024) {
          return `${this.roundMetric(bytes / 1024)}KB`;
        }
        return `${bytes}B`;
      }
    }

    class SwiftWebWASI {
      constructor() {
        this.instance = null;
        this.imports = {
          args_get: () => 0,
          args_sizes_get: (argcPointer, argvBufferSizePointer) => {
            this.view().setUint32(argcPointer, 0, true);
            this.view().setUint32(argvBufferSizePointer, 0, true);
            return 0;
          },
          clock_res_get: (clockID, resolutionPointer) => {
            this.view().setBigUint64(resolutionPointer, 1_000_000n, true);
            return 0;
          },
          clock_time_get: (clockID, precision, timePointer) => {
            this.view().setBigUint64(timePointer, BigInt(Date.now()) * 1_000_000n, true);
            return 0;
          },
          environ_get: () => 0,
          environ_sizes_get: (countPointer, bufferSizePointer) => {
            this.view().setUint32(countPointer, 0, true);
            this.view().setUint32(bufferSizePointer, 0, true);
            return 0;
          },
          fd_close: () => 0,
          fd_fdstat_get: () => 0,
          fd_fdstat_set_flags: () => 0,
          fd_filestat_get: () => 8,
          fd_filestat_set_size: () => 8,
          fd_filestat_set_times: () => 8,
          fd_pread: () => 8,
          fd_prestat_get: () => 8,
          fd_prestat_dir_name: () => 8,
          fd_read: () => 0,
          fd_readdir: () => 8,
          fd_seek: () => 0,
          fd_sync: () => 0,
          fd_tell: (fd, offsetPointer) => {
            this.view().setBigUint64(offsetPointer, 0n, true);
            return 0;
          },
          fd_write: (fd, iovs, iovsLength, writtenPointer) => this.fdWrite(fd, iovs, iovsLength, writtenPointer),
          path_create_directory: () => 44,
          path_filestat_get: () => 44,
          path_filestat_set_times: () => 44,
          path_link: () => 44,
          path_open: () => 44,
          path_readlink: () => 44,
          path_remove_directory: () => 44,
          path_rename: () => 44,
          path_symlink: () => 44,
          path_unlink_file: () => 44,
          poll_oneoff: (subscriptionsPointer, eventsPointer, count, eventCountPointer) => {
            this.view().setUint32(eventCountPointer, 0, true);
            return 0;
          },
          proc_exit: (code) => {
            if (code !== 0) {
              throw new Error(`WASI proc_exit(${code})`);
            }
            return 0;
          },
          random_get: (pointer, length) => {
            crypto.getRandomValues(new Uint8Array(this.memory().buffer, pointer, length));
            return 0;
          }
        };
      }

      bind(instance) {
        this.instance = instance;
      }

      memory() {
        return this.instance.exports.memory;
      }

      view() {
        return new DataView(this.memory().buffer);
      }

      fdWrite(fd, iovs, iovsLength, writtenPointer) {
        const view = this.view();
        let written = 0;
        let output = "";
        for (let index = 0; index < iovsLength; index += 1) {
          const base = iovs + index * 8;
          const pointer = view.getUint32(base, true);
          const length = view.getUint32(base + 4, true);
          const bytes = new Uint8Array(this.memory().buffer, pointer, length);
          output += new TextDecoder().decode(bytes);
          written += length;
        }
        if (writtenPointer) {
          view.setUint32(writtenPointer, written, true);
        }
        if (output.length > 0) {
          if (fd === 2) {
            console.error(output);
          } else {
            console.log(output);
          }
        }
        return 0;
      }
    }

    function findEventTarget(start, eventName) {
      if (!(start instanceof Element)) {
        return null;
      }
      return start.closest(`[${swiftWebRuntimeMarkers.eventAttributePrefix}${eventName}]`);
    }

    // Every `input` event from a text/range/etc. field or textarea is a
    // value-change whose binding only cares about the latest value, so we
    // coalesce them to one dispatch per animation frame. This caps a fast drag
    // or fast typing at ~60 round-trips/sec (last-value-wins) instead of one
    // whole-tree re-render per native event.
    function isCoalescableInputEvent(eventName, target) {
      return eventName === "input"
        && (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement);
    }

    function scheduleAnimationFrame(callback) {
      if (typeof window.requestAnimationFrame === "function") {
        window.requestAnimationFrame(callback);
      } else {
        window.setTimeout(callback, 16);
      }
    }

    function addSwiftNodeSubtree(nodeID, output, runtime, hydrationIndex = runtime.hydrationIndex) {
      if (nodeID === null || nodeID === undefined) {
        return;
      }
      const id = String(rawValue(nodeID));
      output.add(id);
      const root = document.querySelector(`[${swiftWebRuntimeMarkers.nodeAttribute}="${nodeID}"]`);
      if (root) {
        for (const descendant of root.querySelectorAll(`[${swiftWebRuntimeMarkers.nodeAttribute}]`)) {
          const descendantID = descendant.getAttribute(swiftWebRuntimeMarkers.nodeAttribute);
          if (descendantID) {
            output.add(descendantID);
          }
        }
        return;
      }
      const record = nodeRecord(id, runtime, hydrationIndex);
      if (!record) {
        return;
      }
      for (const childID of record.childIDs || []) {
        addSwiftNodeSubtree(rawValue(childID), output, runtime, hydrationIndex);
      }
    }

    function addSwiftDOMSubtree(root, output) {
      const rootNodeID = root.getAttribute(swiftWebRuntimeMarkers.nodeAttribute);
      if (rootNodeID) {
        output.add(rootNodeID);
      }
      for (const descendant of root.querySelectorAll(`[${swiftWebRuntimeMarkers.nodeAttribute}]`)) {
        const descendantID = descendant.getAttribute(swiftWebRuntimeMarkers.nodeAttribute);
        if (descendantID) {
          output.add(descendantID);
        }
      }
    }

    function containsProtectedSwiftNode(element, protectedNodeIDs) {
      for (const descendant of element.querySelectorAll(`[${swiftWebRuntimeMarkers.nodeAttribute}]`)) {
        const nodeID = descendant.getAttribute(swiftWebRuntimeMarkers.nodeAttribute);
        if (nodeID && protectedNodeIDs.has(nodeID)) {
          return true;
        }
      }
      return false;
    }

    function copyElementAttributes(current, next) {
      for (const attribute of Array.from(current.attributes)) {
        current.removeAttribute(attribute.name);
      }
      for (const attribute of Array.from(next.attributes)) {
        current.setAttribute(attribute.name, attribute.value);
      }
    }

    function isDocumentShellElement(element) {
      if (element === document.documentElement || element === document.head || element === document.body) {
        return true;
      }
      if (element.id === "client-runtime" || element.id === "wasm-runtime-metrics") {
        return true;
      }
      return ["HTML", "HEAD", "BODY", "SCRIPT", "STYLE", "META", "TITLE", "LINK"].includes(element.tagName);
    }

    function domEventPayload(event) {
      const target = event.target instanceof HTMLInputElement
        || event.target instanceof HTMLTextAreaElement
        || event.target instanceof HTMLSelectElement
        ? event.target
        : null;

      return {
        value: target ? target.value : null,
        checked: target instanceof HTMLInputElement ? target.checked : null,
        key: "key" in event ? event.key : null,
        code: "code" in event ? event.code : null,
        inputType: "inputType" in event ? event.inputType : null,
        clientX: "clientX" in event ? event.clientX : null,
        clientY: "clientY" in event ? event.clientY : null,
        metadata: {}
      };
    }

    function applyCommandBatch(batch, runtime) {
      if (!batch || !Array.isArray(batch.commands)) {
        return;
      }
      for (const command of orderedCommandsForDOMApplication(batch.commands)) {
        applyCommand(command, runtime);
      }
    }

    function orderedCommandsForDOMApplication(commands) {
      const ordered = [];
      let insertRun = [];
      let insertRunParent = null;

      const flushInsertRun = () => {
        insertRun
          .sort((left, right) => {
            if (left.index !== right.index) {
              return left.index - right.index;
            }
            return left.offset - right.offset;
          })
          .forEach((entry) => ordered.push(entry.command));
        insertRun = [];
        insertRunParent = null;
      };

      commands.forEach((command, offset) => {
        const insertion = insertionTarget(command);
        if (!insertion) {
          flushInsertRun();
          ordered.push(command);
          return;
        }

        if (insertRunParent !== null && insertRunParent !== insertion.parent) {
          flushInsertRun();
        }

        insertRunParent = insertion.parent;
        insertRun.push({
          offset,
          parent: insertion.parent,
          index: insertion.index,
          command
        });
      });

      flushInsertRun();
      return ordered;
    }

    function insertionTarget(command) {
      const name = Object.keys(command)[0];
      const payload = command[name];
      if (name === "insertNode" || name === "insertHTML") {
        return {
          parent: rawValue(payload.parent),
          index: payload.index || 0
        };
      }
      return null;
    }

    function applyCommand(command, runtime) {
      const name = Object.keys(command)[0];
      const payload = command[name];

      switch (name) {
        case "replaceNode":
          replaceNode(payload.node, payload.replacement, runtime);
          break;
        case "replaceSubtree":
          replaceSubtree(payload.node, payload.html, runtime);
          break;
        case "updateText":
          updateText(payload.node, payload.value, runtime);
          break;
        case "updateComment":
          updateComment(payload.node, payload.value, runtime);
          break;
        case "updateAttributes":
          updateAttributes(payload.node, payload.attributes || [], runtime);
          break;
        case "setProperty":
          setProperty(payload.node, payload.name, payload.value, runtime);
          break;
        case "insertNode":
          insertNode(payload.parent, payload.index, payload.node, runtime);
          break;
        case "insertHTML":
          insertHTML(payload.parent, payload.index, payload.html, runtime);
          break;
        case "remove":
          removeNode(payload.parent, payload.index, payload.node, runtime);
          break;
        case "move":
          moveNode(payload.parent, payload.from, payload.to, runtime);
          break;
        case "moveKeyed":
          moveKeyedNode(payload.parent, payload.key, payload.to, runtime);
          break;
        default:
          console.warn(`Unknown SwiftWeb DOM command: ${name}`);
      }
    }

    function replaceNode(nodeID, replacementID, runtime) {
      const node = resolveDOMNode(nodeID, runtime);
      const replacement = resolveDOMNode(replacementID, runtime);
      if (!node || !replacement || !node.parentNode) {
        return;
      }
      node.parentNode.replaceChild(replacement.cloneNode(true), node);
    }

    function replaceSubtree(nodeID, html, runtime) {
      const record = nodeRecord(rawValue(nodeID), runtime);
      if (record && (
        record.role === "component"
        || record.role === "serverSlot"
        || record.role === "fragment"
        || record.role === "document"
      )) {
        if (replaceRenderedRange(record, html, runtime)) {
          return;
        }
      }
      const node = resolveDOMNode(nodeID, runtime);
      if (!node || !node.parentNode) {
        return;
      }
      const nodes = parseHTML(html);
      if (nodes.length === 0) {
        node.remove();
        return;
      }
      node.replaceWith(...nodes);
    }

    function replaceRenderedRange(record, html, runtime) {
      const boundary = renderedBoundary(record, runtime);
      if (!boundary) {
        return false;
      }
      const range = document.createRange();
      range.setStartBefore(boundary.first);
      range.setEndAfter(boundary.last);
      const fragment = range.createContextualFragment(html || "");
      range.deleteContents();
      range.insertNode(fragment);
      return true;
    }

    function renderedBoundary(record, runtime) {
      if (record.role === "component" || record.role === "serverSlot") {
        return boundaryComments(record);
      }
      if (record.role === "fragment" || record.role === "document") {
        const children = record.childIDs || [];
        if (children.length === 0) {
          return null;
        }
        const firstRecord = nodeRecord(rawValue(children[0]), runtime);
        const lastRecord = nodeRecord(rawValue(children[children.length - 1]), runtime);
        if (!firstRecord || !lastRecord) {
          return null;
        }
        const firstBoundary = renderedBoundary(firstRecord, runtime);
        const lastBoundary = renderedBoundary(lastRecord, runtime);
        const first = firstBoundary ? firstBoundary.first : resolveDOMNode(firstRecord.id, runtime);
        const last = lastBoundary ? lastBoundary.last : resolveDOMNode(lastRecord.id, runtime);
        return first && last ? { first, last } : null;
      }
      const node = resolveDOMNode(record.id, runtime);
      return node ? { first: node, last: node } : null;
    }

    function boundaryComments(record) {
      const prefix = boundaryPrefix(record);
      if (!prefix) {
        return null;
      }
      const walker = document.createTreeWalker(document, NodeFilter.SHOW_COMMENT);
      let begin = null;
      while (true) {
        const node = walker.nextNode();
        if (!node) {
          return null;
        }
        if (node.nodeValue === `${prefix}:begin`) {
          begin = node;
        } else if (node.nodeValue === `${prefix}:end` && begin) {
          return { first: begin, last: node };
        }
      }
    }

    function boundaryPrefix(record) {
      if (record.role === "component" && record.componentID) {
        return `${swiftWebRuntimeMarkers.componentCommentPrefix}:${rawValue(record.componentID)}`;
      }
      if (record.role === "serverSlot" && record.serverSlotID) {
        return `${swiftWebRuntimeMarkers.serverSlotCommentPrefix}:${rawValue(record.serverSlotID)}`;
      }
      return null;
    }

    function updateText(nodeID, value, runtime) {
      const node = resolveDOMNode(nodeID, runtime);
      if (node) {
        node.textContent = value || "";
      }
    }

    function updateComment(nodeID, value, runtime) {
      const node = resolveDOMNode(nodeID, runtime);
      if (node) {
        node.textContent = value || "";
      }
    }

    function updateAttributes(nodeID, attributes, runtime) {
      const node = resolveElement(nodeID, runtime);
      if (!node) {
        return;
      }
      const internalNode = node.getAttribute(swiftWebRuntimeMarkers.nodeAttribute);
      const internalKey = node.getAttribute(swiftWebRuntimeMarkers.keyAttribute);
      const nextNames = new Set(attributes.map((attribute) => attribute.name));
      for (const attribute of Array.from(node.attributes)) {
        if (attribute.name === swiftWebRuntimeMarkers.nodeAttribute || attribute.name === swiftWebRuntimeMarkers.keyAttribute) {
          continue;
        }
        if (!nextNames.has(attribute.name)) {
          node.removeAttribute(attribute.name);
        }
      }
      for (const attribute of attributes) {
        if (attribute.value === null || attribute.value === undefined) {
          node.setAttribute(attribute.name, "");
        } else {
          node.setAttribute(attribute.name, attribute.value);
        }
      }
      if (internalNode !== null) {
        node.setAttribute(swiftWebRuntimeMarkers.nodeAttribute, internalNode);
      }
      if (internalKey !== null) {
        node.setAttribute(swiftWebRuntimeMarkers.keyAttribute, internalKey);
      }
    }

    function setProperty(nodeID, name, value, runtime) {
      const node = resolveElement(nodeID, runtime);
      if (!node) {
        return;
      }
      if (name === "checked" || name === "disabled" || name === "selected") {
        node[name] = value === "true";
        if (value === "true") {
          node.setAttribute(name, "");
        } else {
          node.removeAttribute(name);
        }
        return;
      }
      node[name] = value === null || value === undefined ? "" : value;
      if (value === null || value === undefined) {
        node.removeAttribute(name);
      } else {
        node.setAttribute(name, value);
      }
    }

    function insertNode(parentID, index, nodeID, runtime) {
      const context = mutationContext(parentID, index, runtime);
      const node = resolveDOMNode(nodeID, runtime);
      if (!context || !node) {
        return;
      }
      context.parent.insertBefore(node, context.reference || null);
    }

    function insertHTML(parentID, index, html, runtime) {
      const context = mutationContext(parentID, index, runtime);
      if (!context) {
        return;
      }
      const nodes = parseHTML(html);
      for (const node of nodes) {
        context.parent.insertBefore(node, context.reference || null);
      }
    }

    function removeNode(parentID, index, nodeID, runtime) {
      const record = nodeRecord(rawValue(nodeID), runtime);
      if (record && removeRenderedNode(record, runtime)) {
        return;
      }
      const context = mutationContext(parentID, index, runtime);
      const node = resolveDOMNode(nodeID, runtime) || (context ? context.parent.childNodes[index] : null);
      if (context && node && node.parentNode === context.parent) {
        context.parent.removeChild(node);
      }
    }

    function moveNode(parentID, from, to, runtime) {
      const parentRecord = nodeRecord(rawValue(parentID), runtime);
      if (parentRecord) {
        const childID = (parentRecord.childIDs || [])[from];
        const childRecord = childID === undefined ? null : nodeRecord(rawValue(childID), runtime);
        if (childRecord && moveRenderedNode(parentRecord, childRecord, to, runtime)) {
          return;
        }
      }
      const context = mutationContext(parentID, from, runtime);
      if (!context) {
        return;
      }
      const node = context.parent.childNodes[from];
      if (node) {
        const destination = mutationContext(parentID, to, runtime);
        context.parent.removeChild(node);
        context.parent.insertBefore(node, destination ? destination.reference || null : null);
      }
    }

    function moveKeyedNode(parentID, key, to, runtime) {
      const parentRecord = nodeRecord(rawValue(parentID), runtime);
      const identity = domKeyIdentity(key);
      if (parentRecord && identity) {
        const childRecord = (parentRecord.childIDs || [])
          .map((childID) => nodeRecord(rawValue(childID), runtime))
          .find((record) => record && record.key && domKeyIdentity(record.key) === identity);
        if (childRecord && moveRenderedNode(parentRecord, childRecord, to, runtime)) {
          return;
        }
      }
      const context = mutationContext(parentID, to, runtime);
      if (!context || !identity) {
        return;
      }
      const node = Array.from(context.parent.children).find((child) => child.getAttribute(swiftWebRuntimeMarkers.keyAttribute) === identity);
      if (node) {
        context.parent.insertBefore(node, context.reference || null);
      }
    }

    function parseHTML(html) {
      const template = document.createElement("template");
      template.innerHTML = html || "";
      return Array.from(template.content.childNodes);
    }

    function mutationContext(parentID, index, runtime) {
      const record = nodeRecord(rawValue(parentID), runtime);
      if (!record) {
        const parent = resolveElement(parentID, runtime);
        return parent ? { parent, reference: parent.childNodes[index] || null } : null;
      }

      if (record.role === "element") {
        const parent = resolveElement(record.id, runtime);
        return parent ? { parent, reference: referenceNodeForLogicalIndex(record, index, runtime) } : null;
      }

      if (record.role === "component" || record.role === "serverSlot") {
        const boundary = boundaryComments(record);
        if (!boundary || !boundary.first.parentNode) {
          return null;
        }
        return {
          parent: boundary.first.parentNode,
          reference: referenceNodeForLogicalIndex(record, index, runtime) || boundary.last
        };
      }

      if (record.role === "fragment" || record.role === "document") {
        const boundary = renderedBoundary(record, runtime);
        if (boundary && boundary.first.parentNode) {
          return {
            parent: boundary.first.parentNode,
            reference: referenceNodeForLogicalIndex(record, index, runtime) || boundary.last.nextSibling
          };
        }
        return transparentContainerContext(record, runtime);
      }

      const parent = resolveElement(record.id, runtime);
      return parent ? { parent, reference: parent.childNodes[index] || null } : null;
    }

    function referenceNodeForLogicalIndex(record, index, runtime) {
      const children = record.childIDs || [];
      for (let cursor = Math.max(0, index); cursor < children.length; cursor += 1) {
        const childRecord = nodeRecord(rawValue(children[cursor]), runtime);
        if (!childRecord) {
          continue;
        }
        const boundary = renderedBoundary(childRecord, runtime);
        if (boundary && boundary.first.parentNode) {
          return boundary.first;
        }
        const node = resolveDOMNode(childRecord.id, runtime);
        if (node && node.parentNode) {
          return node;
        }
      }
      return null;
    }

    function transparentContainerContext(record, runtime) {
      if (record.role === "document") {
        const parent = document.body || document.documentElement;
        return parent ? { parent, reference: null } : null;
      }
      if (!record.parentID) {
        return null;
      }
      const parentRecord = nodeRecord(rawValue(record.parentID), runtime);
      if (!parentRecord) {
        return null;
      }
      const index = (parentRecord.childIDs || [])
        .map((childID) => rawValue(childID))
        .indexOf(rawValue(record.id));
      if (index < 0) {
        return null;
      }
      return mutationContext(parentRecord.id, index + 1, runtime);
    }

    function removeRenderedNode(record, runtime) {
      const boundary = renderedBoundary(record, runtime);
      if (boundary) {
        const range = document.createRange();
        range.setStartBefore(boundary.first);
        range.setEndAfter(boundary.last);
        range.deleteContents();
        return true;
      }
      const node = resolveDOMNode(record.id, runtime);
      if (node && node.parentNode) {
        node.parentNode.removeChild(node);
        return true;
      }
      return false;
    }

    function moveRenderedNode(parentRecord, record, destinationIndex, runtime) {
      const boundary = renderedBoundary(record, runtime);
      const context = mutationContext(parentRecord.id, destinationIndex, runtime);
      if (!boundary || !context) {
        return false;
      }
      if (context.reference && renderedRangeContains(boundary, context.reference)) {
        return true;
      }
      const range = document.createRange();
      range.setStartBefore(boundary.first);
      range.setEndAfter(boundary.last);
      const fragment = range.extractContents();
      context.parent.insertBefore(fragment, context.reference || null);
      return true;
    }

    function renderedRangeContains(boundary, target) {
      let node = boundary.first;
      while (node) {
        if (node === target) {
          return true;
        }
        if (node === boundary.last) {
          return false;
        }
        node = node.nextSibling;
      }
      return false;
    }

    function domKeyIdentity(key) {
      if (!key) {
        return null;
      }
      return key.identity || key.rawValue || String(key);
    }

    function resolveElement(nodeID, runtime) {
      const node = resolveDOMNode(nodeID, runtime);
      return node instanceof Element ? node : null;
    }

    function resolveDOMNode(nodeID, runtime) {
      const id = rawValue(nodeID);
      const direct = document.querySelector(`[${swiftWebRuntimeMarkers.nodeAttribute}="${id}"]`);
      if (direct) {
        return direct;
      }
      const record = nodeRecord(id, runtime);
      if (!record) {
        return null;
      }
      if (record.role === "text" || record.role === "comment" || record.role === "placeholder") {
        return resolveRenderedChild(record, runtime);
      }
      return null;
    }

    function resolveRenderedChild(record, runtime) {
      if (!record.parentID) {
        return null;
      }
      const parent = resolveDOMNode(record.parentID, runtime);
      const parentRecord = nodeRecord(rawValue(record.parentID), runtime);
      if (!parent || !parentRecord) {
        return null;
      }
      let domIndex = 0;
      for (const childID of parentRecord.childIDs) {
        const childRawID = rawValue(childID);
        if (childRawID === rawValue(record.id)) {
          return parent.childNodes[domIndex] || null;
        }
        domIndex += renderedNodeCount(childRawID, runtime);
      }
      return null;
    }

    function renderedNodeCount(nodeID, runtime) {
      const record = nodeRecord(nodeID, runtime);
      if (!record) {
        return 0;
      }
      if (record.role === "fragment" || record.role === "document") {
        return (record.childIDs || []).reduce((total, childID) => total + renderedNodeCount(rawValue(childID), runtime), 0);
      }
      if (record.role === "component" || record.role === "serverSlot") {
        return 2 + (record.childIDs || []).reduce((total, childID) => total + renderedNodeCount(rawValue(childID), runtime), 0);
      }
      return 1;
    }

    function nodeRecord(nodeID, runtime, hydrationIndex = runtime.hydrationIndex) {
      if (!hydrationIndex || !Array.isArray(hydrationIndex.nodes)) {
        return null;
      }
      const id = String(rawValue(nodeID));
      return hydrationIndex.nodes.find((node) => String(rawValue(node.id)) === id) || null;
    }

    function rawValue(value) {
      if (typeof value === "number") {
        return value;
      }
      if (typeof value === "string") {
        return value;
      }
      if (value && typeof value.rawValue === "number") {
        return value.rawValue;
      }
      if (value && typeof value.rawValue === "string") {
        return value.rawValue;
      }
      return String(value);
    }

    function stateSchemaHash(slots) {
      const lines = (slots || [])
        .slice()
        .sort((left, right) => String(rawValue(left.id)).localeCompare(String(rawValue(right.id))))
        .map((slot) => [
          rawValue(slot.id),
          slot.valueType || "",
          sourceLocationValue(slot.source)
        ].join("|"));
      return stableSchemaHash(lines.join("\n"));
    }

    function environmentSchemaHash(snapshot) {
      const lines = ((snapshot && snapshot.values) || [])
        .slice()
        .sort((left, right) => {
          if ((left.key || "") === (right.key || "")) {
            return (left.valueType || "").localeCompare(right.valueType || "");
          }
          return (left.key || "").localeCompare(right.key || "");
        })
        .map((value) => [
          value.key || "",
          value.valueType || "",
          value.encoding || ""
        ].join("|"));
      return stableSchemaHash(lines.join("\n"));
    }

    function sourceLocationValue(source) {
      if (!source) {
        return "";
      }
      if (source.rawValue) {
        return source.rawValue;
      }
      return `${source.fileID || ""}:${source.line || 0}:${source.column || 0}`;
    }

    function stableSchemaHash(value) {
      let hash = 0xcbf29ce484222325n;
      const bytes = new TextEncoder().encode(value || "");
      for (const byte of bytes) {
        hash ^= BigInt(byte);
        hash = BigInt.asUintN(64, hash * 0x100000001b3n);
      }
      return hash.toString(16).padStart(16, "0");
    }

    function navigationAnchorForEvent(event) {
      if (!event || event.defaultPrevented) {
        return null;
      }
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
        return null;
      }
      const path = eventPath(event);
      let anchor = null;
      for (const item of path) {
        if (!(item instanceof Element)) {
          continue;
        }
        if (item.hasAttribute(`${swiftWebRuntimeMarkers.eventAttributePrefix}click`)) {
          return null;
        }
        if (item.matches("a[href]")) {
          anchor = item;
          break;
        }
      }
      if (!anchor || anchor.hasAttribute("download")) {
        return null;
      }
      const target = (anchor.getAttribute("target") || "").toLowerCase();
      if (target && target !== "_self") {
        return null;
      }
      const href = anchor.getAttribute("href");
      if (!href || href.startsWith("#")) {
        return null;
      }
      let url;
      try {
        url = new URL(href, window.location.href);
      } catch {
        return null;
      }
      if (url.origin !== window.location.origin) {
        return null;
      }
      if (url.protocol !== "http:" && url.protocol !== "https:") {
        return null;
      }
      const current = new URL(window.location.href);
      if (url.pathname === current.pathname && url.search === current.search) {
        return null;
      }
      return anchor;
    }

    function findServerActionSubmitter(event) {
      const path = eventPath(event);
      for (const item of path) {
        if (!(item instanceof Element)) {
          continue;
        }
        if (item.matches("[data-server-action-button=\"true\"]")) {
          return item;
        }
        if (item.matches("button[type=\"submit\"], input[type=\"submit\"]")) {
          return item;
        }
      }
      return null;
    }

    function findServerActionForm(event, submitter) {
      if (submitter instanceof Element) {
        const submitterForm = submitter.closest("form[data-server-action=\"true\"]");
        if (submitterForm) {
          return submitterForm;
        }
      }
      const path = eventPath(event);
      for (const item of path) {
        if (item instanceof Element && item.matches("form[data-server-action=\"true\"]")) {
          return item;
        }
      }
      const target = event.target instanceof Element ? event.target : null;
      return target ? target.closest("form[data-server-action=\"true\"]") : null;
    }

    function appendFormDataToURL(formData, url) {
      for (const [name, value] of formData.entries()) {
        if (typeof value === "string") {
          url.searchParams.append(name, value);
        } else {
          url.searchParams.append(name, value.name || "");
        }
      }
    }

    function eventPath(event) {
      if (event && typeof event.composedPath === "function") {
        return event.composedPath();
      }
      const path = [];
      let current = event ? event.target : null;
      while (current) {
        path.push(current);
        current = current.parentNode;
      }
      path.push(window);
      return path;
    }

    const descriptorElement = document.getElementById("client-runtime");

    if (descriptorElement) {
      const descriptor = JSON.parse(descriptorElement.textContent || "{}");

      if (descriptor.mode === "wasm" && descriptor.wasm) {
        const runtime = new SwiftWebWasmRuntime(descriptor);
        window.__swiftWebWasmRuntime = runtime;
        runtime.start().catch((error) => {
          const status = {
            ready: false,
            phase: "failed",
            error: String(error && error.message ? error.message : error)
          };
          window.__swiftWebWasmRuntimeStatus = status;
          window.dispatchEvent(new CustomEvent("wasmStatus", { detail: status }));
          runtime.recordFailure(error);
          console.error("SwiftWeb WASM runtime failed", error);
        });
      }
    }
    """#
}
