import SwiftWebBrowserRuntime

extension Request {
    var clientSecurityDescriptor: ClientSecurityDescriptor? {
        let security = application.securityConfiguration
        guard security.csrf.isEnabled else {
            return nil
        }
        return ClientSecurityDescriptor(
            csrfToken: securityContext?.csrfToken,
            csrfHeaderName: security.csrf.headerName.rawName,
            csrfFieldName: securityContext?.csrfFieldName ?? security.csrf.formFieldName
        )
    }
}
