import Foundation

/// Security-scoped bookmarks: how a sandboxed app keeps access to files the user
/// picked once. The platform differences live here and nowhere else.
nonisolated enum SecurityScopedBookmark {
    static func make(for url: URL) throws -> Data {
        try url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: resolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    #if os(macOS)
    // The sandbox grants read-only access to user-selected files (`user-selected.read-only`), so
    // the bookmark must ask for read-only scope too. A default (read-write) scope can only be
    // created where the app could also write, e.g. inside its own container — which is why this
    // goes unnoticed with files in the container but fails for a file picked from Downloads.
    private static let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
    #else
    // On iOS, security scope is carried by the bookmark itself.
    private static let creationOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withoutUI]
    #endif
}

/// Holds a security-scoped resource open until `stop()` is called.
///
/// `startAccessingSecurityScopedResource()` returns false for URLs that need no
/// scope (e.g. files inside the app container); `stop()` then correctly does nothing.
final class SecurityScopedAccess {
    let url: URL
    private var isActive: Bool

    init(url: URL) {
        self.url = url
        self.isActive = url.startAccessingSecurityScopedResource()
    }

    func stop() {
        guard isActive else { return }
        url.stopAccessingSecurityScopedResource()
        isActive = false
    }
}
