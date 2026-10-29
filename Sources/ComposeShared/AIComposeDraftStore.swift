import Foundation

// An inbox shared by the main app, the system Social compose extension and
// the Action extension. It stores drafts locally: there is deliberately NO
// network call, AI submission or automatic upload.
//
// Both extension processes must have the same App Group entitlement as the
// containing app. If the App Group is unavailable, writing fails explicitly
// rather than storing data in a private extension container that the app
// cannot read.

struct AIComposeAttachment: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let relativePath: String
    let typeIdentifier: String
    let sizeInBytes: Int64
    let source: String
}

struct AIComposeDraft: Codable, Sendable {
    let id: String
    let createdAt: Date
    let message: String
    let source: String
    let sharedText: [String]
    let attachments: [AIComposeAttachment]
}

enum AIComposeStoreError: LocalizedError {
    case appGroupUnavailable
    case notAFile
    case fileTooLarge
    case tooManyFiles
    case invalidAttachment
    case emptyDraft

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "Shared App Group storage is unavailable."
        case .notAFile:
            return "The shared attachment is not a file."
        case .fileTooLarge:
            return "An attachment exceeds the allowed file size."
        case .tooManyFiles:
            return "Too many attachments in this draft."
        case .invalidAttachment:
            return "An attachment cannot be accessed."
        case .emptyDraft:
            return "Add text or an attachment before saving."
        }
    }
}

enum AIComposeDraftStore {
    static let directoryName = "AIComposeInbox"
    static let lastDraftIDKey = "aiComposeInbox.latestDraftID.v1"
    static let maximumFiles = 20
    static let maximumFileBytes: Int64 = 80 * 1024 * 1024

    static func sessionDirectory(id: String, create: Bool) throws -> URL {
        guard let container = AppEnvironment.sharedContainerURL else {
            throw AIComposeStoreError.appGroupUnavailable
        }
        // Caller-generated UUIDs are the only supported directory names.
        guard UUID(uuidString: id) != nil else {
            throw AIComposeStoreError.invalidAttachment
        }
        let path = container
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
        if create {
            try FileManager.default.createDirectory(
                at: path,
                withIntermediateDirectories: true
            )
        }
        return path
    }

    static func safeDisplayName(_ proposed: String?) -> String {
        let last = URL(fileURLWithPath: proposed ?? "").lastPathComponent
        let cleaned = String(
            last.unicodeScalars
                .filter { scalar in
                    scalar.value >= 32
                        && scalar.value != 47
                        && scalar.value != 92
                        && scalar.value != 58
                }
                .prefix(120)
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty || cleaned == "."
            ? "attachment"
            : cleaned
    }

    static func stageFile(
        from sourceURL: URL,
        in sessionID: String,
        displayName: String?,
        typeIdentifier: String,
        source: String
    ) throws -> AIComposeAttachment {
        guard sourceURL.isFileURL else {
            throw AIComposeStoreError.notAFile
        }

        let filename = safeDisplayName(displayName ?? sourceURL.lastPathComponent)
        let size = try Int64(
            (FileManager.default.attributesOfItem(
                atPath: sourceURL.path
            )[.size] as? NSNumber)?.int64Value ?? 0
        )
        guard size <= maximumFileBytes else {
            throw AIComposeStoreError.fileTooLarge
        }

        let directory = try sessionDirectory(id: sessionID, create: true)
        let attachmentID = UUID().uuidString
        let fileExtension = URL(fileURLWithPath: filename).pathExtension
        let storedFilename = attachmentID
            + (fileExtension.isEmpty ? "" : "." + fileExtension)
        let destination = directory.appendingPathComponent(storedFilename)

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        return AIComposeAttachment(
            id: attachmentID,
            name: filename,
            relativePath: storedFilename,
            typeIdentifier: typeIdentifier,
            sizeInBytes: size,
            source: source
        )
    }

    static func stageData(
        _ data: Data,
        in sessionID: String,
        displayName: String,
        typeIdentifier: String,
        source: String
    ) throws -> AIComposeAttachment {
        guard Int64(data.count) <= maximumFileBytes else {
            throw AIComposeStoreError.fileTooLarge
        }
        let directory = try sessionDirectory(id: sessionID, create: true)
        let attachmentID = UUID().uuidString
        let safeName = safeDisplayName(displayName)
        let fileExtension = URL(fileURLWithPath: safeName).pathExtension
        let storedFilename = attachmentID
            + (fileExtension.isEmpty ? "" : "." + fileExtension)
        try data.write(
            to: directory.appendingPathComponent(storedFilename),
            options: .atomic
        )
        return AIComposeAttachment(
            id: attachmentID,
            name: safeName,
            relativePath: storedFilename,
            typeIdentifier: typeIdentifier,
            sizeInBytes: Int64(data.count),
            source: source
        )
    }

    static func save(
        sessionID: String,
        message: String,
        source: String,
        sharedText: [String],
        attachments: [AIComposeAttachment]
    ) throws -> AIComposeDraft {
        guard attachments.count <= maximumFiles else {
            throw AIComposeStoreError.tooManyFiles
        }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || !sharedText.isEmpty
              || !attachments.isEmpty else {
            throw AIComposeStoreError.emptyDraft
        }

        let folder = try sessionDirectory(id: sessionID, create: true)
        let draft = AIComposeDraft(
            id: sessionID,
            createdAt: Date(),
            message: message,
            source: source,
            sharedText: sharedText,
            attachments: attachments
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(draft)
        try data.write(to: folder.appendingPathComponent("draft.json"), options: .atomic)

        // The manifest must be written before the pointer is published.
        guard let defaults = UserDefaults(suiteName: AppEnvironment.appGroupID) else {
            throw AIComposeStoreError.appGroupUnavailable
        }
        defaults.set(sessionID, forKey: lastDraftIDKey)
        return draft
    }

    static func lastDraft() -> AIComposeDraft? {
        guard AppEnvironment.sharedContainerURL != nil,
              let defaults = UserDefaults(suiteName: AppEnvironment.appGroupID),
              let id = defaults.string(forKey: lastDraftIDKey),
              let folder = try? sessionDirectory(id: id, create: false),
              let data = try? Data(
                contentsOf: folder.appendingPathComponent("draft.json")
              ) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AIComposeDraft.self, from: data)
    }

    static func lastDraftJSONString() -> String {
        guard let draft = lastDraft() else {
            return #"{"status":"no_shared_draft"}"#
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let bytes = try? encoder.encode(draft),
              let text = String(data: bytes, encoding: .utf8) else {
            return #"{"status":"encoding_failed"}"#
        }
        return text
    }

    static func fileURL(for attachment: AIComposeAttachment, in draft: AIComposeDraft) -> URL? {
        guard attachment.relativePath == URL(fileURLWithPath: attachment.relativePath).lastPathComponent,
              let directory = try? sessionDirectory(id: draft.id, create: false) else {
            return nil
        }
        let url = directory.appendingPathComponent(attachment.relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func discardUnsentSession(id: String) {
        // Only discard the folder of a session that has not become the latest
        // completed draft. Keep completed content available to the main app.
        let publishedID = UserDefaults(
            suiteName: AppEnvironment.appGroupID
        )?.string(forKey: lastDraftIDKey)
        guard publishedID != id,
              let folder = try? sessionDirectory(id: id, create: false) else {
            return
        }
        try? FileManager.default.removeItem(at: folder)
    }
}
