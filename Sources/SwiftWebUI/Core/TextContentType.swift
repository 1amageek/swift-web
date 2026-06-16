import SwiftHTML

/// The semantic meaning of the text a control expects, mirroring SwiftUI
/// `textContentType(_:)` / UIKit `UITextContentType`.
///
/// Each case maps to the corresponding HTML `autocomplete` token so browsers and
/// password managers can offer the right autofill.
public enum TextContentType: String, Sendable {
    case name = "name"
    case givenName = "given-name"
    case familyName = "family-name"
    case nickname = "nickname"
    case organizationName = "organization"
    case jobTitle = "organization-title"
    case username = "username"
    case password = "current-password"
    case newPassword = "new-password"
    case oneTimeCode = "one-time-code"
    case emailAddress = "email"
    case telephoneNumber = "tel"
    case URL = "url"
    case fullStreetAddress = "street-address"
    case addressCity = "address-level2"
    case addressState = "address-level1"
    case postalCode = "postal-code"
    case countryName = "country-name"
    case creditCardNumber = "cc-number"

    var autocompleteToken: String {
        rawValue
    }
}
