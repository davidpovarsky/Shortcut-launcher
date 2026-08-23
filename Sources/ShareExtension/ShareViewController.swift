@preconcurrency import Foundation
@preconcurrency import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private enum Mode: String {
        case compact
        case medium
        case expanded

        var title: String {
            switch self {
            case .compact: return "Dav Compact"
            case .medium: return "Dav Medium"
            case .expanded: return "Dav Expanded"
            }
        }

        var subtitle: String {
            switch self {
            case .compact:
                return "Minimal share UI • requested height 220 pt"
            case .medium:
                return "Balanced share UI • requested height 460 pt"
            case .expanded:
                return "Expanded diagnostics UI • requested height 760 pt"
            }
        }

        var requestedSize: CGSize {
            switch self {
            case .compact: return CGSize(width: 420, height: 220)
            case .medium: return CGSize(width: 540, height: 460)
            case .expanded: return CGSize(width: 720, height: 760)
            }
        }

        var bodyFont: UIFont {
            switch self {
            case .compact: return .preferredFont(forTextStyle: .footnote)
            case .medium: return .preferredFont(forTextStyle: .body)
            case .expanded: return .preferredFont(forTextStyle: .body)
            }
        }
    }

    private lazy var mode: Mode = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "ShareLabMode") as? String
        return Mode(rawValue: raw ?? "") ?? .medium
    }()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let sizeLabel = UILabel()
    private let typeLabel = UILabel()
    private let payloadTextView = UITextView()
    private let statusLabel = UILabel()
    private var pendingLoads = 0
    private var payloadSummaries: [String] = []
    private var observedTypeIdentifiers: [String] = []
    private var lastLoggedBounds = CGSize.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = mode.requestedSize
        configureInterface()
        recordLifecycle("shareLab.viewDidLoad")
        loadSharedItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        preferredContentSize = mode.requestedSize
        recordLifecycle("shareLab.viewWillAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recordLifecycle("shareLab.viewDidAppear")
        updateSizeLabel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSizeLabel()

        let current = view.bounds.size
        guard abs(current.width - lastLoggedBounds.width) >= 1 || abs(current.height - lastLoggedBounds.height) >= 1 else {
            return
        }
        lastLoggedBounds = current
        DiagnosticLog.record(
            "shareLab.layout",
            details: [
                "mode": mode.rawValue,
                "requested": sizeString(mode.requestedSize),
                "actual": sizeString(current),
                "safeArea": insetString(view.safeAreaInsets),
                "traits.horizontalSizeClass": sizeClassString(traitCollection.horizontalSizeClass),
                "traits.verticalSizeClass": sizeClassString(traitCollection.verticalSizeClass)
            ]
        )
    }

    private func configureInterface() {
        view.backgroundColor = .systemGroupedBackground

        titleLabel.font = .preferredFont(forTextStyle: mode == .compact ? .headline : .title2)
        titleLabel.text = mode.title
        titleLabel.numberOfLines = 1

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.text = mode.subtitle
        subtitleLabel.numberOfLines = 2

        sizeLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        sizeLabel.textColor = .secondaryLabel
        sizeLabel.numberOfLines = 2

        typeLabel.font = .preferredFont(forTextStyle: .caption1)
        typeLabel.textColor = .secondaryLabel
        typeLabel.numberOfLines = mode == .compact ? 1 : 3
        typeLabel.lineBreakMode = .byTruncatingTail
        typeLabel.text = "Inspecting shared input…"

        payloadTextView.isEditable = false
        payloadTextView.isSelectable = true
        payloadTextView.backgroundColor = mode == .compact ? .clear : .secondarySystemGroupedBackground
        payloadTextView.layer.cornerRadius = mode == .compact ? 0 : 12
        payloadTextView.font = mode.bodyFont
        payloadTextView.textContainerInset = mode == .compact
            ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            : UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        payloadTextView.text = "Loading shared content…"
        payloadTextView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        statusLabel.font = .preferredFont(forTextStyle: .caption2)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 1
        statusLabel.text = "The system may override the requested share-extension size."

        let doneButton = UIButton(type: .system)
        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = "Done"
        doneConfig.cornerStyle = .medium
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(finishSharing), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        var cancelConfig = UIButton.Configuration.gray()
        cancelConfig.title = "Cancel"
        cancelConfig.cornerStyle = .medium
        cancelButton.configuration = cancelConfig
        cancelButton.addTarget(self, action: #selector(cancelSharing), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, doneButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 3

        let rootStack = UIStackView(arrangedSubviews: [headerStack, sizeLabel, typeLabel, payloadTextView, statusLabel, buttonStack])
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.axis = .vertical
        rootStack.spacing = mode == .compact ? 6 : 12
        rootStack.isLayoutMarginsRelativeArrangement = true
        rootStack.layoutMargins = UIEdgeInsets(
            top: mode == .compact ? 12 : 18,
            left: mode == .compact ? 14 : 20,
            bottom: mode == .compact ? 12 : 18,
            right: mode == .compact ? 14 : 20
        )
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            buttonStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 42)
        ])

        switch mode {
        case .compact:
            payloadTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
            statusLabel.isHidden = true
        case .medium:
            payloadTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        case .expanded:
            payloadTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
            statusLabel.text = "Expanded mode keeps more payload and sizing diagnostics visible for comparison."
        }
    }

    private func loadSharedItems() {
        let extensionItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = extensionItems.flatMap { $0.attachments ?? [] }

        observedTypeIdentifiers = providers.flatMap(\.registeredTypeIdentifiers)
        let uniqueTypes = Array(Set(observedTypeIdentifiers)).sorted()
        typeLabel.text = uniqueTypes.isEmpty
            ? "No attachment type identifiers received"
            : "Types: " + uniqueTypes.joined(separator: ", ")

        DiagnosticLog.record(
            "shareLab.input.received",
            details: [
                "mode": mode.rawValue,
                "extensionItems": String(extensionItems.count),
                "providers": String(providers.count),
                "typeIdentifiers": uniqueTypes.joined(separator: ",")
            ]
        )

        guard !providers.isEmpty else {
            payloadTextView.text = extensionItems.compactMap(\.attributedContentText).map(\.string).joined(separator: "\n")
            if payloadTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payloadTextView.text = "No attachment payload was supplied by the host app."
            }
            return
        }

        pendingLoads = providers.count
        payloadSummaries.removeAll(keepingCapacity: true)

        for (index, provider) in providers.enumerated() {
            guard let typeIdentifier = preferredTypeIdentifier(for: provider) else {
                finishProviderLoad(
                    index: index,
                    typeIdentifier: "unknown",
                    summary: "Item \(index + 1): provider had no registered type identifiers"
                )
                continue
            }

            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
                let summary = Self.describeLoadedItem(
                    item,
                    error: error,
                    index: index,
                    typeIdentifier: typeIdentifier
                )
                DispatchQueue.main.async {
                    self?.finishProviderLoad(index: index, typeIdentifier: typeIdentifier, summary: summary)
                }
            }
        }
    }

    private func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        let priority = [
            UTType.fileURL.identifier,
            UTType.url.identifier,
            UTType.plainText.identifier,
            UTType.image.identifier,
            UTType.movie.identifier,
            UTType.data.identifier
        ]

        return priority.first(where: { provider.hasItemConformingToTypeIdentifier($0) })
            ?? provider.registeredTypeIdentifiers.first
    }

    nonisolated private static func describeLoadedItem(
        _ item: NSSecureCoding?,
        error: Error?,
        index: Int,
        typeIdentifier: String
    ) -> String {
        let prefix = "Item \(index + 1) [\(typeIdentifier)]"
        if let error {
            return "\(prefix)\nError: \(error.localizedDescription)"
        }
        if let url = item as? URL {
            if url.isFileURL {
                return "\(prefix)\nFile: \(url.lastPathComponent)\n\(url.path)"
            }
            return "\(prefix)\nURL: \(url.absoluteString)"
        }
        if let text = item as? String {
            return "\(prefix)\nText: \(text)"
        }
        if let text = item as? NSString {
            return "\(prefix)\nText: \(text as String)"
        }
        if let image = item as? UIImage {
            return "\(prefix)\nImage: \(Int(image.size.width))×\(Int(image.size.height)) pt"
        }
        if let data = item as? Data {
            return "\(prefix)\nData: \(data.count) bytes"
        }
        if let item {
            return "\(prefix)\nObject: \(String(describing: type(of: item)))"
        }
        return "\(prefix)\nNo value returned"
    }

    private func finishProviderLoad(index: Int, typeIdentifier: String, summary: String) {
        payloadSummaries.append(summary)
        pendingLoads = max(0, pendingLoads - 1)

        DiagnosticLog.record(
            "shareLab.input.loaded",
            details: [
                "mode": mode.rawValue,
                "index": String(index),
                "typeIdentifier": typeIdentifier,
                "summary": String(summary.prefix(240))
            ]
        )

        payloadTextView.text = payloadSummaries.joined(separator: "\n\n")
        if pendingLoads == 0 {
            statusLabel.text = "Loaded \(payloadSummaries.count) shared item(s). Compare requested vs actual size above."
            DiagnosticLog.record(
                "shareLab.input.complete",
                details: [
                    "mode": mode.rawValue,
                    "loaded": String(payloadSummaries.count),
                    "actual": sizeString(view.bounds.size)
                ]
            )
        }
    }

    private func updateSizeLabel() {
        sizeLabel.text = "Requested: \(sizeString(mode.requestedSize))   Actual: \(sizeString(view.bounds.size))"
    }

    private func recordLifecycle(_ event: String) {
        DiagnosticLog.record(
            event,
            details: [
                "mode": mode.rawValue,
                "requested": sizeString(mode.requestedSize),
                "actual": sizeString(view.bounds.size),
                "presentationStyle": String(describing: modalPresentationStyle),
                "host": Bundle.main.bundleIdentifier ?? "nil"
            ]
        )
        DiagnosticLog.recordEnvironment(event)
    }

    @objc private func finishSharing() {
        DiagnosticLog.record(
            "shareLab.complete",
            details: [
                "mode": mode.rawValue,
                "actual": sizeString(view.bounds.size),
                "payloadCount": String(payloadSummaries.count)
            ]
        )
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func cancelSharing() {
        DiagnosticLog.record(
            "shareLab.cancel",
            details: ["mode": mode.rawValue, "actual": sizeString(view.bounds.size)]
        )
        let error = NSError(
            domain: "DavLauncher.ShareLab",
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Share lab cancelled by user"]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private func sizeString(_ size: CGSize) -> String {
        "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private func insetString(_ insets: UIEdgeInsets) -> String {
        "t\(Int(insets.top.rounded()))-l\(Int(insets.left.rounded()))-b\(Int(insets.bottom.rounded()))-r\(Int(insets.right.rounded()))"
    }

    private func sizeClassString(_ sizeClass: UIUserInterfaceSizeClass) -> String {
        switch sizeClass {
        case .compact: return "compact"
        case .regular: return "regular"
        case .unspecified: return "unspecified"
        @unknown default: return "unknown"
        }
    }
}
