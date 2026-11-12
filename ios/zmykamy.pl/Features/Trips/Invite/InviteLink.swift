import Foundation

/// Recognizes trip invite links (`https://zmykamy.pl/j/LIZ-6K2PX9QM`), whether opened as a link or scanned from a QR code.
nonisolated enum InviteLink {
    /// Hosts that serve invite links; the API host covers older links and the local backend in debug builds.
    static let trustedHosts: Set<String> = Set(
        ["zmykamy.pl", "www.zmykamy.pl", APIConfiguration.baseURL.host()?.lowercased()].compactMap(\.self)
    )

    #if DEBUG
    private static let allowedSchemes: Set<String> = ["https", "http"]
    #else
    private static let allowedSchemes: Set<String> = ["https"]
    #endif

    /// Returns the invite slug when `text` is an invite link from a trusted host.
    static func slug(from text: String) -> String? {
        URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap(slug(from:))
    }

    /// Returns the invite slug when `url` is an invite link from a trusted host.
    static func slug(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme),
              let host = url.host()?.lowercased(), trustedHosts.contains(host)
        else { return nil }

        let components = url.pathComponents
        guard components.count == 3, components[1] == "j" else { return nil }
        let slug = components[2]
        guard slug.wholeMatch(of: /[A-Za-z]{1,3}-[A-Za-z0-9]{8}/) != nil else { return nil }
        return slug
    }
}
