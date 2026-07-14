import HTTPTypes

public enum CSRFTokenSource: Sendable {
    case header
    case formField
    case headerOrFormField

    var allowsHeader: Bool {
        switch self {
        case .header, .headerOrFormField:
            true
        case .formField:
            false
        }
    }

    var allowsFormField: Bool {
        switch self {
        case .formField, .headerOrFormField:
            true
        case .header:
            false
        }
    }
}

public struct CSRFPolicy: Sendable {
    public var isEnabled: Bool
    public var cookieName: String
    public var formFieldName: String
    public var headerName: HTTPField.Name
    public var tokenByteCount: Int
    public var cookieMaxAge: Int?
    public var cookieIsSecure: Bool
    public var cookieSameSite: CookieValue.SameSitePolicy
    public var protectedMethods: Set<String>
    public var formTokenSource: CSRFTokenSource
    public var uploadTokenSource: CSRFTokenSource

    public init(
        isEnabled: Bool = true,
        cookieName: String = "csrf_token",
        formFieldName: String = "_csrf",
        headerName: HTTPField.Name = HTTPField.Name("X-CSRF-Token")!,
        tokenByteCount: Int = 32,
        cookieMaxAge: Int? = 86_400,
        cookieIsSecure: Bool = false,
        cookieSameSite: CookieValue.SameSitePolicy = .lax,
        protectedMethods: Set<String> = ["POST", "PUT", "PATCH", "DELETE"],
        formTokenSource: CSRFTokenSource = .headerOrFormField,
        uploadTokenSource: CSRFTokenSource = .header
    ) {
        self.isEnabled = isEnabled
        self.cookieName = cookieName
        self.formFieldName = formFieldName
        self.headerName = headerName
        self.tokenByteCount = tokenByteCount
        self.cookieMaxAge = cookieMaxAge
        self.cookieIsSecure = cookieIsSecure
        self.cookieSameSite = cookieSameSite
        self.protectedMethods = protectedMethods
        self.formTokenSource = formTokenSource
        self.uploadTokenSource = uploadTokenSource
    }

    public static let disabled = CSRFPolicy(isEnabled: false)

    public static let enabled = CSRFPolicy()

    func protects(_ method: HTTPRequest.Method) -> Bool {
        protectedMethods.contains(method.rawValue.uppercased())
    }

    func cookieValue(token: String) -> CookieValue {
        CookieValue(
            string: token,
            maxAge: cookieMaxAge,
            path: "/",
            isSecure: cookieIsSecure,
            isHTTPOnly: true,
            sameSite: cookieSameSite
        )
    }
}
