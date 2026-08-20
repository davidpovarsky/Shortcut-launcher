import Foundation

enum AppEnvironment {
    static let fallbackAppGroupID = "group.com.dav.DavLauncher"

    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "LauncherAppGroupIdentifier") as? String
            ?? fallbackAppGroupID
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
