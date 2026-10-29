@preconcurrency import Foundation
@preconcurrency import UIKit
import UniformTypeIdentifiers

/// Shared input and file picker coordinator used by both the standard Apple
/// Social composer and a separate Action extension entry.
///
/// NSItemProvider's temporary file is copied *inside its completion handler*;
/// Apple deletes it when the handler returns.
@MainActor
final class AIComposeInputController: NSObject, UIDocumentPickerDelegate {
    let sessionID = UUID().uuidString
    private(set) var attachments: [AIComposeAttachment] = []
    private(set) var sharedText: [String] = []
    private(set) var errors: [String] = []
    private(set) var pendingProviders = 0
    private(set) var waitingForPicker = false
    var didChange: (() -> Void)?

    var isBusy: Bool {
        pendingProviders > 0 || waitingForPicker
    }

    var statusText: String {
        if isBusy {
            return "טוען קבצים…"
        }
        if !errors.isEmpty {
            return "\(attachments.count) קבצים · \(errors.count) שגיאות"
        }
        return attachments.isEmpty
            ? "הוסף קובץ…"
            : "\(attachments.count) קבצים · הוסף עוד…"
    }

    func receiveSharedItems(_ items: [NSExtensionItem]) {
        for item in items {
            if let text = item.attributedContentText?.string,
               !text.isEmpty {
                sharedText.append(text)
            }

            for provider in item.attachments ?? [] {
                guard attachments.count + pendingProviders
                        < AIComposeDraftStore.maximumFiles else {
                    errors.append("יותר מדי קבצים מצורפים")
                    continue
                }
                load(provider)
            }
        }
        didChange?()
    }

    func showDocumentPicker(from parent: UIViewController) {
        guard !waitingForPicker else { return }
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.allowsMultipleSelection = true
        picker.delegate = self
        waitingForPicker = true
        didChange?()
        parent.present(picker, animated: true)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        waitingForPicker = false
        for url in urls {
            guard attachments.count < AIComposeDraftStore.maximumFiles else {
                errors.append("מגבלת 20 הקבצים הושגה")
                break
            }
            do {
                let item = try AIComposeDraftStore.stageFile(
                    from: url,
                    in: sessionID,
                    displayName: url.lastPathComponent,
                    typeIdentifier: (try? url.resourceValues(
                        forKeys: [.contentTypeKey]
                    ).contentType?.identifier) ?? UTType.data.identifier,
                    source: "file-picker"
                )
                attachments.append(item)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        didChange?()
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        waitingForPicker = false
        didChange?()
    }

    func commit(text: String, source: String) throws -> AIComposeDraft {
        guard !isBusy else {
            throw AIComposeStoreError.invalidAttachment
        }
        return try AIComposeDraftStore.save(
            sessionID: sessionID,
            message: text,
            source: source,
            sharedText: sharedText,
            attachments: attachments
        )
    }

    func cancel() {
        AIComposeDraftStore.discardUnsentSession(id: sessionID)
    }

    private func load(_ provider: NSItemProvider) {
        // Avoid treating plain text / web URLs as binary file attachments.
        // Their content becomes sharedText in the saved draft.
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           !provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            loadTextRepresentation(provider, type: .url)
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           !provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           !provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           !provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            loadTextRepresentation(provider, type: .plainText)
            return
        }

        let type: String
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            type = UTType.fileURL.identifier
        } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            type = UTType.pdf.identifier
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            type = UTType.image.identifier
        } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            type = UTType.movie.identifier
        } else {
            type = provider.registeredTypeIdentifiers.first ?? UTType.data.identifier
        }

        let filename = provider.suggestedName
            ?? ("shared-item-" + UUID().uuidString.prefix(8)
                + (UTType(type)?.preferredFilenameExtension.map { "." + $0 } ?? ""))
        let sessionID = self.sessionID

        pendingProviders += 1
        didChange?()

        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
            let result: Result<AIComposeAttachment, Error>
            if let url {
                result = Result {
                    try AIComposeDraftStore.stageFile(
                        from: url,
                        in: sessionID,
                        displayName: filename,
                        typeIdentifier: type,
                        source: "share-sheet"
                    )
                }
            } else {
                result = .failure(
                    error ?? AIComposeStoreError.invalidAttachment
                )
            }

            DispatchQueue.main.async { [weak self] in
                self?.finishProviderLoad(result)
            }
        }
    }

    private func loadTextRepresentation(_ provider: NSItemProvider, type: UTType) {
        pendingProviders += 1
        didChange?()
        provider.loadDataRepresentation(for: type) { [weak self] data, error in
            let text = data.flatMap { String(data: $0, encoding: .utf8) }
            let description = error?.localizedDescription
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingProviders = max(0, self.pendingProviders - 1)
                if let text,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.sharedText.append(String(text.prefix(40_000)))
                } else {
                    self.errors.append(
                        description ?? "לא ניתן לקרוא את הטקסט ששותף"
                    )
                }
                self.didChange?()
            }
        }
    }

    private func finishProviderLoad(_ result: Result<AIComposeAttachment, Error>) {
        pendingProviders = max(0, pendingProviders - 1)
        switch result {
        case .success(let item):
            attachments.append(item)
        case .failure(let error):
            errors.append(error.localizedDescription)
        }
        didChange?()
    }
}
