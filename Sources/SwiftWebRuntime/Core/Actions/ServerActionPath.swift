#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
public enum ServerActionPath {
    public static func renderedPath(_ path: String) -> String {
        if isAbsolute(path) {
            return normalized(path)
        }

        let basePath = RequestContext.current?.request.url.path ?? "/"
        return joined(basePath: basePath, relativePath: path)
    }

    static func routePath(for path: String, basePath: RoutePath) -> RoutePath {
        if isAbsolute(path) {
            return RoutePath(path)
        }
        return RoutePath(basePath.components + RoutePath(path).components)
    }

    private static func isAbsolute(_ path: String) -> Bool {
        path.hasPrefix("/")
    }

    private static func normalized(_ path: String) -> String {
        RoutePath(path).string
    }

    private static func joined(basePath: String, relativePath: String) -> String {
        let base = RoutePath(basePath).components
        let relative = RoutePath(relativePath).components
        return RoutePath(base + relative).string
    }
}
#endif
