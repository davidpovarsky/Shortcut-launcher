import Foundation

enum AppEnvironment {
    static let fallbackAppGroupID = "group.com.dav.DavLauncher"

    static var configuredAppGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "LauncherAppGroupIdentifier") as? String
            ?? fallbackAppGroupID
    }

    /// The unsigned/ad-hoc CI build uses the original App Group identifier,
    /// while SideStore appends the current Team ID when it provisions the app.
    /// The extension bundle IDs may contain an extra component before that suffix,
    /// for example `com.dav.DavLauncher.SefariaPreview.NA6HPWARQ2`, so resolve the
    /// final 10-character component rather than assuming the first suffix component.
    static var appGroupCandidates: [String] {
        var candidates = [configuredAppGroupID]
        if let teamIdentifier = sideStoreTeamIdentifier {
            candidates.append(configuredAppGroupID + "." + teamIdentifier)
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    static var sideStoreTeamIdentifier: String? {
        let configuredGroup = configuredAppGroupID
        let baseBundleIdentifier: String
        if configuredGroup.hasPrefix("group.") {
            baseBundleIdentifier = String(configuredGroup.dropFirst("group.".count))
        } else {
            baseBundleIdentifier = configuredGroup
        }

        guard let installedBundleIdentifier = Bundle.main.bundleIdentifier,
              installedBundleIdentifier.hasPrefix(baseBundleIdentifier) else {
            return nil
        }

        let remainder = String(installedBundleIdentifier.dropFirst(baseBundleIdentifier.count))
        guard remainder.hasPrefix(".") else { return nil }

        let components = remainder
            .dropFirst()
            .split(separator: ".", omittingEmptySubsequences: true)
            .map(String.init)

        return components.reversed().first(where: isLikelySideStoreTeamIdentifier)
    }

    private static func isLikelySideStoreTeamIdentifier(_ candidate: String) -> Bool {
        guard candidate.count == 10 else { return false }
        return candidate.unicodeScalars.allSatisfy {
            CharacterSet.uppercaseLetters.contains($0) || CharacterSet.decimalDigits.contains($0)
        }
    }

    private static var resolvedSharedContainer: (id: String, url: URL)? {
        for candidate in appGroupCandidates {
            if let url = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: candidate
            ) {
                return (candidate, url)
            }
        }
        return nil
    }

    /// Effective App Group ID for this installed build. On a normal Xcode build
    /// this is the configured ID; on a SideStore-provisioned build it is the
    /// Team-ID-suffixed group that SideStore created and placed in the profile.
    static var appGroupID: String {
        resolvedSharedContainer?.id ?? configuredAppGroupID
    }

    static var sharedContainerURL: URL? {
        resolvedSharedContainer?.url
    }

    static var appGroupResolutionDescription: String {
        if let resolved = resolvedSharedContainer {
            return resolved.id == configuredAppGroupID ? "configured" : "sidestore-team-suffix"
        }
        return "missing"
    }

    static var sharedDefaults: UserDefaults {
        if resolvedSharedContainer != nil,
           let defaults = UserDefaults(suiteName: appGroupID) {
            return defaults
        }
        return .standard
    }

    static var isMainAppProcess: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundlePackageType") as? String) == "APPL"
    }

    static var processRole: String {
        if isMainAppProcess {
            return "main-app"
        }

        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if bundleID.contains("SefariaPreview") {
            return "quicklook-sefaria-preview-extension"
        }
        if bundleID.contains("Widgets") {
            return "widget-extension"
        }
        if Bundle.main.bundleURL.pathExtension == "appex" {
            return "app-extension"
        }
        return "unknown-extension"
    }
}
