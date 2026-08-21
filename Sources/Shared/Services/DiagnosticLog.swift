import Foundation

enum DiagnosticLog {
    static let logFileName = "DavLauncher-Diagnostics.log"
    static let documentsFolderName = "DavLauncher Logs"

    static var sharedLogURL: URL? {
        AppEnvironment.sharedContainerURL?.appendingPathComponent(logFileName, isDirectory: false)
    }

    static var documentsLogURL: URL? {
        guard AppEnvironment.isMainAppProcess,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents
            .appendingPathComponent(documentsFolderName, isDirectory: true)
            .appendingPathComponent(logFileName, isDirectory: false)
    }

    static var filesLocationDescription: String {
        "On My iPad > Dav Launcher > \(documentsFolderName) > \(logFileName)"
    }

    static func record(
        _ event: String,
        details: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())

        var fields: [String: String] = [
            "event": event,
            "pid": String(ProcessInfo.processInfo.processIdentifier),
            "role": AppEnvironment.processRole,
            "bundle": Bundle.main.bundleIdentifier ?? "nil",
            "source": "\(file):\(line)",
            "function": function
        ]
        details.forEach { fields[$0.key] = $0.value }

        let payload = fields.keys.sorted().map { key in
            "\(key)=\(sanitize(fields[key] ?? ""))"
        }.joined(separator: " | ")

        let entry = "[\(timestamp)] \(payload)\n"
        print(entry, terminator: "")

        if let sharedURL = sharedLogURL {
            append(entry, to: sharedURL)
            if AppEnvironment.isMainAppProcess {
                syncSharedLogToDocuments()
            }
        } else if let documentsURL = documentsLogURL {
            append(entry, to: documentsURL)
        }
    }

    static func recordEnvironment(_ reason: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "nil"
        record(
            "environment.snapshot",
            details: [
                "reason": reason,
                "configuredAppGroupID": AppEnvironment.configuredAppGroupID,
                "effectiveAppGroupID": AppEnvironment.appGroupID,
                "appGroupCandidates": AppEnvironment.appGroupCandidates.joined(separator: ","),
                "appGroupResolution": AppEnvironment.appGroupResolutionDescription,
                "sideStoreTeamIdentifier": AppEnvironment.sideStoreTeamIdentifier ?? "nil",
                "appGroupContainerAvailable": String(AppEnvironment.sharedContainerURL != nil),
                "appGroupContainerPath": AppEnvironment.sharedContainerURL?.path ?? "nil",
                "documentsPath": documentsPath,
                "bundlePath": Bundle.main.bundleURL.path,
                "bundlePackageType": Bundle.main.object(forInfoDictionaryKey: "CFBundlePackageType") as? String ?? "nil"
            ]
        )
    }

    static func syncSharedLogToDocuments() {
        guard AppEnvironment.isMainAppProcess,
              let destination = documentsLogURL else {
            return
        }

        do {
            try ensureParentDirectory(for: destination)
            if let source = sharedLogURL, FileManager.default.fileExists(atPath: source.path) {
                let data = try Data(contentsOf: source)
                try data.write(to: destination, options: .atomic)
            } else if !FileManager.default.fileExists(atPath: destination.path) {
                try Data().write(to: destination, options: .atomic)
            }
        } catch {
            print("DiagnosticLog sync failed: \(error)")
        }
    }

    static func readCurrentLog() -> String {
        let candidates = [sharedLogURL, documentsLogURL].compactMap { $0 }
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return ""
    }

    static func clear() {
        for url in [sharedLogURL, documentsLogURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
        if AppEnvironment.isMainAppProcess {
            syncSharedLogToDocuments()
        }
    }

    private static func append(_ string: String, to url: URL) {
        do {
            try ensureParentDirectory(for: url)
            let data = Data(string.utf8)

            if !FileManager.default.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
                return
            }

            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("DiagnosticLog append failed at \(url.path): \(error)")
        }
    }

    private static func ensureParentDirectory(for url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "|", with: "\\|")
    }
}
