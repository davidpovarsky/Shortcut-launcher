@preconcurrency import UIKit

/// Action-extension twin of the standard Social composer. Action extensions
/// cannot rely on SLComposeServiceViewController's Share-service-only system
/// UI, so this target uses a small native UIKit form with the SAME local inbox.
/// It appears in the share sheet's actions section as "Dav AI Compose Action".
final class AIComposeActionViewController: UIViewController, UITextViewDelegate {
    private let inbox = AIComposeInputController()
    private let titleLabel = UILabel()
    private let textView = UITextView()
    private let sourceLabel = UILabel()
    private let attachmentsLabel = UILabel()
    private let statusLabel = UILabel()
    private let saveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 510, height: 490)
        buildInterface()
        inbox.didChange = { [weak self] in
            self?.updateState()
        }
        inbox.receiveSharedItems(
            extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        )
        updateState()
        DiagnosticLog.record(
            "aiCompose.action.present",
            details: ["appGroup": AppEnvironment.appGroupResolutionDescription]
        )
    }

    private func buildInterface() {
        view.backgroundColor = .systemGroupedBackground

        titleLabel.text = "Dav AI Compose"
        titleLabel.font = .preferredFont(forTextStyle: .title2)

        let subtitle = UILabel()
        subtitle.text = "הודעה וקבצים לסוכן · נשמרים באפליקציה"
        subtitle.textColor = .secondaryLabel
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.numberOfLines = 2

        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.layer.cornerRadius = 12
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(
            top: 12, left: 10, bottom: 12, right: 10
        )
        textView.delegate = self
        textView.accessibilityLabel = "הקלד הודעה לסוכן"

        sourceLabel.textColor = .secondaryLabel
        sourceLabel.font = .preferredFont(forTextStyle: .caption1)
        sourceLabel.numberOfLines = 2

        attachmentsLabel.font = .preferredFont(forTextStyle: .footnote)
        attachmentsLabel.numberOfLines = 4
        attachmentsLabel.textColor = .secondaryLabel

        statusLabel.font = .preferredFont(forTextStyle: .caption2)
        statusLabel.numberOfLines = 2
        statusLabel.textColor = .secondaryLabel

        let attachButton = UIButton(type: .system)
        var attachStyle = UIButton.Configuration.gray()
        attachStyle.title = "צרף קבצים"
        attachStyle.image = UIImage(systemName: "paperclip")
        attachStyle.imagePadding = 6
        attachButton.configuration = attachStyle
        attachButton.addTarget(
            self,
            action: #selector(openFilePicker),
            for: .touchUpInside
        )

        var saveStyle = UIButton.Configuration.filled()
        saveStyle.title = "שמור לסוכן"
        saveStyle.image = UIImage(systemName: "checkmark")
        saveStyle.imagePadding = 6
        saveButton.configuration = saveStyle
        saveButton.addTarget(
            self,
            action: #selector(saveDraft),
            for: .touchUpInside
        )

        let cancelButton = UIButton(type: .system)
        var cancelStyle = UIButton.Configuration.gray()
        cancelStyle.title = "ביטול"
        cancelButton.configuration = cancelStyle
        cancelButton.addTarget(
            self,
            action: #selector(cancelDraft),
            for: .touchUpInside
        )

        let actions = UIStackView(
            arrangedSubviews: [cancelButton, saveButton]
        )
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 10

        let root = UIStackView(
            arrangedSubviews: [
                titleLabel,
                subtitle,
                textView,
                sourceLabel,
                attachmentsLabel,
                attachButton,
                statusLabel,
                actions
            ]
        )
        root.axis = .vertical
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        root.isLayoutMarginsRelativeArrangement = true
        root.layoutMargins = UIEdgeInsets(
            top: 18, left: 20, bottom: 18, right: 20
        )

        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor
            ),
            root.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor
            ),
            root.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            root.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor
            ),
            textView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 150
            ),
            actions.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 42
            )
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        updateState()
    }

    private func updateState() {
        let text = textView.text?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        saveButton.isEnabled = !inbox.isBusy
            && (!text.isEmpty
                || !inbox.sharedText.isEmpty
                || !inbox.attachments.isEmpty)

        let names = inbox.attachments.map(\.name)
        attachmentsLabel.text = names.isEmpty
            ? "אין קבצים מצורפים"
            : names.prefix(6).joined(separator: " · ")
        sourceLabel.text = inbox.sharedText.isEmpty
            ? "ניתן לשתף כאן קובץ, קישור או טקסט"
            : "טקסט ששותף: " + String(
                inbox.sharedText.joined(separator: " ").prefix(140)
            )
        statusLabel.text = inbox.statusText + (
            inbox.errors.isEmpty ? "" : " · חלק מהקבצים לא נקראו"
        )
    }

    @objc private func openFilePicker() {
        inbox.showDocumentPicker(from: self)
    }

    @objc private func saveDraft() {
        do {
            let draft = try inbox.commit(
                text: textView.text ?? "",
                source: "share-sheet-action"
            )
            DiagnosticLog.record(
                "aiCompose.action.saved",
                details: [
                    "draftID": draft.id,
                    "attachments": String(draft.attachments.count),
                    "messageLength": String(draft.message.count)
                ]
            )
            extensionContext?.completeRequest(returningItems: [])
        } catch {
            let alert = UIAlertController(
                title: "השמירה נכשלה",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "אישור", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func cancelDraft() {
        inbox.cancel()
        extensionContext?.cancelRequest(
            withError: NSError(
                domain: "DavLauncher.AICompose",
                code: NSUserCancelledError,
                userInfo: [
                    NSLocalizedDescriptionKey: "User cancelled the AI compose action"
                ]
            )
        )
    }
}
