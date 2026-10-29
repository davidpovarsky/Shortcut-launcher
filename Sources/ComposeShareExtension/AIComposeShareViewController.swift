@preconcurrency import UIKit
import Social

/// Dedicated Share extension using Apple's own standard composition sheet:
/// text editor, system Post/Cancel, input preview and config rows.
/// It appears in the *share destinations* area, independently of the existing
/// Compact/Medium/Expanded experimental share extensions.
final class AIComposeShareViewController: SLComposeServiceViewController {
    private let inbox = AIComposeInputController()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dav AI Compose"

        inbox.didChange = { [weak self] in
            guard let self else { return }
            self.reloadConfigurationItems()
            self.validateContent()
        }
        inbox.receiveSharedItems(
            extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        )
        DiagnosticLog.record(
            "aiCompose.systemShare.present",
            details: ["appGroup": AppEnvironment.appGroupResolutionDescription]
        )
    }

    override func isContentValid() -> Bool {
        let text = (contentText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !inbox.isBusy
            && (!text.isEmpty
                || !inbox.sharedText.isEmpty
                || !inbox.attachments.isEmpty)
    }

    override func configurationItems() -> [Any]! {
        guard let attachmentsRow = SLComposeSheetConfigurationItem() else {
            return []
        }
        attachmentsRow.title = "צירוף קבצים"
        attachmentsRow.value = inbox.statusText
        attachmentsRow.valuePending = inbox.isBusy
        attachmentsRow.tapHandler = { [weak self] in
            guard let self else { return }
            self.inbox.showDocumentPicker(from: self)
        }
        return [attachmentsRow]
    }

    override func didSelectPost() {
        do {
            let draft = try inbox.commit(
                text: contentText ?? "",
                source: "system-share-compose"
            )
            DiagnosticLog.record(
                "aiCompose.systemShare.saved",
                details: [
                    "draftID": draft.id,
                    "attachments": String(draft.attachments.count),
                    "messageLength": String(draft.message.count)
                ]
            )
            // This is a local draft for the AI agent, not an upload.
            // Post is the Apple system button; SLCompose supplies the UI.
            extensionContext?.completeRequest(returningItems: [])
        } catch {
            DiagnosticLog.record(
                "aiCompose.systemShare.failed",
                details: ["reason": error.localizedDescription]
            )
            extensionContext?.cancelRequest(withError: error)
        }
    }

    override func didSelectCancel() {
        inbox.cancel()
        DiagnosticLog.record("aiCompose.systemShare.cancel")
        super.didSelectCancel()
    }
}
