import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SpotlightItemLabView: View {
    @State private var items: [SpotlightLabItemConfiguration] = []
    @State private var matrixToken = "elephant"
    @State private var status = ""
    @State private var showingResetConfirmation = false
    @State private var nativeProbeTitle = "Sefaria Native Probe"
    @State private var nativeProbeText = "Jewish library of Torah, Talmud, Mishnah, Midrash, Halakha and commentaries"
    @State private var nativeProbeStatus = "Not indexed"

    var body: some View {
        List {
            Section {
                Text("Edit Core Spotlight metadata at runtime, then reindex immediately. No rebuild is required for changes made here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Reindex Enabled Items", systemImage: "arrow.clockwise") {
                    saveAndReindex(reason: "spotlightLab.manualReindex")
                }

                Button("Remove All Lab Items", systemImage: "trash", role: .destructive) {
                    SefariaSpotlightLab.removeItems(reason: "spotlightLab.manualRemove")
                    status = "Remove request sent"
                    DiagnosticLog.syncSharedLogToDocuments()
                }

                if !status.isEmpty {
                    Text(status)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Index Controls")
            }

            Section {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Spotlight items",
                        systemImage: "magnifyingglass",
                        description: Text("Create an item or restore the default Sefaria experiments.")
                    )
                }

                ForEach(items) { item in
                    NavigationLink {
                        SpotlightItemEditorView(item: item) { updated, shouldReindex in
                            update(updated)
                            if shouldReindex {
                                saveAndReindex(reason: "spotlightLab.editor.saveAndReindex")
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.experimentLabel)
                                    .font(.headline)
                                Spacer()
                                if !item.enabled {
                                    Text("Disabled")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(item.title.isEmpty ? "(no title)" : item.title)
                                .font(.subheadline)
                            Text(item.uniqueIdentifier)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text(item.previewMode.title)
                                if item.semanticMode != .none {
                                    Text("• \(item.semanticMode.title)")
                                }
                                if !item.customAttributes.isEmpty {
                                    Text("• \(item.customAttributes.count) custom")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            duplicate(item)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                }

                Button("New Spotlight Item", systemImage: "plus") {
                    var item = SpotlightLabItemConfiguration()
                    item.experimentLabel = "New Experiment"
                    item.title = "Search Sefaria"
                    items.append(item)
                    persist(reason: "spotlightLab.newItem")
                }
            } header: {
                Text("Spotlight Items")
            } footer: {
                Text("Swipe an item left to duplicate or delete it. Opening an item exposes searchable fields, ranking signals, custom keys, semantic indexing and Quick Look behavior.")
            }

            Section {
                TextField("Test token", text: $matrixToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Generate 8-Item Attribute Matrix", systemImage: "square.grid.2x2") {
                    let matrix = SpotlightItemLabStore.generateAttributeMatrix(token: matrixToken)
                    items.append(contentsOf: matrix)
                    persist(reason: "spotlightLab.matrix.generated")
                    saveAndReindex(reason: "spotlightLab.matrix.reindex")
                    status = "Generated and indexed 8 matrix items"
                }

                Text("The test token is now isolated to exactly one tested field in each A–H item. Shared descriptions no longer contain the token, so a result cannot pass because of accidental metadata contamination.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Experiment Matrix")
            }

            Section {
                TextField("Result title", text: $nativeProbeTitle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Semantic / searchable text", text: $nativeProbeText, axis: .vertical)
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Index Native Semantic Probes", systemImage: "sparkles") {
                    nativeProbeStatus = "Indexing…"
                    Task {
                        do {
                            try await SpotlightNativeProbeService.indexProbes(
                                title: nativeProbeTitle,
                                searchableText: nativeProbeText
                            )
                            nativeProbeStatus = "Indexed generic + Messages schema probes"
                        } catch {
                            nativeProbeStatus = "Error: \(error.localizedDescription)"
                            DiagnosticLog.record("spotlight.nativeProbes.uiFailed", details: ["error": String(describing: error)])
                        }
                    }
                }

                Button("Remove Native Semantic Probes", systemImage: "trash", role: .destructive) {
                    Task {
                        do {
                            try await SpotlightNativeProbeService.removeProbes()
                            nativeProbeStatus = "Removed"
                        } catch {
                            nativeProbeStatus = "Remove error: \(error.localizedDescription)"
                        }
                    }
                }

                LabeledContent("Probe status", value: nativeProbeStatus)

                Text("This indexes two compile-time entity types: a normal IndexedEntity with explicit @ComputedProperty(indexingKey:) fields, and an @AppEntity(schema: .messages.message) probe whose body maps to Spotlight textContent. Change the values here and reindex without rebuilding.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Native IndexedEntity Probes")
            }

            Section {
                Button("Copy Full Configuration JSON", systemImage: "doc.on.doc") {
                    copyJSON(items)
                }

                Button("Append Item(s) JSON from Clipboard", systemImage: "plus.rectangle.on.folder") {
                    appendClipboardJSON()
                }

                Button("Replace Full Configuration from Clipboard", systemImage: "doc.on.clipboard") {
                    replaceConfigurationFromClipboard()
                }

                Button("Restore Default Sefaria Items", systemImage: "arrow.counterclockwise", role: .destructive) {
                    showingResetConfirmation = true
                }
            } header: {
                Text("Configuration")
            } footer: {
                Text("Append accepts either one item object or an array and keeps existing items. Replace Full Configuration retains the old behavior and replaces the entire list.")
            }
        }
        .navigationTitle("Spotlight Item Lab")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            items = SpotlightItemLabStore.items
            nativeProbeTitle = SpotlightNativeProbeService.savedTitle
            nativeProbeText = SpotlightNativeProbeService.savedSearchableText
            DiagnosticLog.record("spotlight.lab.ui.opened", details: ["count": String(items.count)])
        }
        .confirmationDialog(
            "Restore the three default Sefaria items?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore Defaults", role: .destructive) {
                items = SpotlightItemLabStore.resetToDefaults()
                saveAndReindex(reason: "spotlightLab.restoreDefaults")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func update(_ item: SpotlightLabItemConfiguration) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        persist(reason: "spotlightLab.item.updated")
    }

    private func duplicate(_ item: SpotlightLabItemConfiguration) {
        items.append(SpotlightItemLabStore.duplicate(item))
        persist(reason: "spotlightLab.item.duplicated")
    }

    private func delete(_ item: SpotlightLabItemConfiguration) {
        items.removeAll { $0.id == item.id }
        persist(reason: "spotlightLab.item.deleted")
    }

    private func persist(reason: String) {
        SpotlightItemLabStore.save(items, reason: reason)
    }

    private func saveAndReindex(reason: String) {
        persist(reason: reason)
        SefariaSpotlightLab.indexItems(reason: reason)
        status = "Index request sent for \(items.filter(\.enabled).count) enabled items"
        DiagnosticLog.syncSharedLogToDocuments()
    }

    private func copyJSON(_ value: [SpotlightLabItemConfiguration]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            status = "Could not encode JSON"
            return
        }
        UIPasteboard.general.string = string
        status = "Configuration JSON copied"
        DiagnosticLog.record("spotlight.lab.json.copied", details: ["count": String(value.count)])
    }

    private func replaceConfigurationFromClipboard() {
        guard let decoded = clipboardItems(), !decoded.isEmpty else {
            status = "Clipboard does not contain valid Spotlight Lab JSON"
            return
        }
        items = decoded
        persist(reason: "spotlightLab.json.replaced")
        status = "Replaced configuration with \(decoded.count) item(s) — tap Reindex"
    }

    private func appendClipboardJSON() {
        guard let decoded = clipboardItems(), !decoded.isEmpty else {
            status = "Clipboard does not contain a valid item or item array"
            return
        }

        var existingIDs = Set(items.map(\.id))
        var existingIdentifiers = Set(items.map(\.uniqueIdentifier))
        var additions: [SpotlightLabItemConfiguration] = []

        for original in decoded {
            var item = original
            if existingIDs.contains(item.id) {
                item.id = UUID()
            }
            if existingIdentifiers.contains(item.uniqueIdentifier) {
                item.uniqueIdentifier += ".imported.\(UUID().uuidString.lowercased().prefix(8))"
            }
            existingIDs.insert(item.id)
            existingIdentifiers.insert(item.uniqueIdentifier)
            additions.append(item)
        }

        items.append(contentsOf: additions)
        persist(reason: "spotlightLab.json.appended")
        status = "Appended \(additions.count) item(s) — tap Reindex"
    }

    private func clipboardItems() -> [SpotlightLabItemConfiguration]? {
        guard let string = UIPasteboard.general.string,
              let data = string.data(using: .utf8) else {
            return nil
        }
        if let array = try? JSONDecoder().decode([SpotlightLabItemConfiguration].self, from: data) {
            return array
        }
        if let item = try? JSONDecoder().decode(SpotlightLabItemConfiguration.self, from: data) {
            return [item]
        }
        return nil
    }
}

private struct SpotlightItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SpotlightLabItemConfiguration
    @State private var status = ""

    let onSave: (SpotlightLabItemConfiguration, Bool) -> Void

    init(
        item: SpotlightLabItemConfiguration,
        onSave: @escaping (SpotlightLabItemConfiguration, Bool) -> Void
    ) {
        _draft = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Experiment") {
                Toggle("Enabled", isOn: $draft.enabled)
                TextField("Experiment label", text: $draft.experimentLabel)
                TextField("Unique identifier", text: $draft.uniqueIdentifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Domain identifier", text: $draft.domainIdentifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Content type preset", selection: $draft.contentTypeIdentifier) {
                    Text("Generic item").tag(UTType.item.identifier)
                    Text("Text").tag(UTType.text.identifier)
                    Text("Plain text").tag(UTType.plainText.identifier)
                    Text("Data").tag(UTType.data.identifier)
                    Text("Email message").tag(UTType.emailMessage.identifier)
                    Text("Custom / current value").tag(draft.contentTypeIdentifier)
                }
                TextField("UTType identifier", text: $draft.contentTypeIdentifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                StringArrayField("Content type tree", values: $draft.contentTypeTree)

                Stepper("Expiration: \(draft.expirationDays == 0 ? "default" : "\(draft.expirationDays) days")", value: $draft.expirationDays, in: 0...365)
                Toggle("Mark as update", isOn: $draft.isUpdate)
            }

            Section("Primary Search Metadata") {
                TextField("Title", text: $draft.title, axis: .vertical)
                TextField("Display name", text: $draft.displayName, axis: .vertical)
                StringArrayField("Alternate names", values: $draft.alternateNames)
                StringArrayField("Keywords", values: $draft.keywords)
                TextField("Content description", text: $draft.contentDescription, axis: .vertical)
                    .lineLimit(2...6)
                TextField("Text content", text: $draft.textContent, axis: .vertical)
                    .lineLimit(3...10)
                TextField("Subject", text: $draft.subject, axis: .vertical)
                TextField("Theme", text: $draft.theme, axis: .vertical)
                TextField("Creator", text: $draft.creator)
                StringArrayField("Audiences", values: $draft.audiences)
            }

            Section("Container / Grouping") {
                TextField("Container identifier", text: $draft.containerIdentifier)
                TextField("Container title", text: $draft.containerTitle)
                TextField("Container display name", text: $draft.containerDisplayName)
                Stepper("Container order: \(draft.containerOrder)", value: $draft.containerOrder, in: -1000...1000)
            }

            Section {
                StringArrayField("Author names", values: $draft.authorNames)
                StringArrayField("Author addresses", values: $draft.authorAddresses)
                StringArrayField("Author email addresses", values: $draft.authorEmailAddresses)
                StringArrayField("Recipient names", values: $draft.recipientNames)
                StringArrayField("Recipient addresses", values: $draft.recipientAddresses)
                StringArrayField("Recipient email addresses", values: $draft.recipientEmailAddresses)
                StringArrayField("All email addresses", values: $draft.emailAddresses)
                StringArrayField("Mailbox identifiers", values: $draft.mailboxIdentifiers)
                StringArrayField("Account handles", values: $draft.accountHandles)
                TextField("Account identifier", text: $draft.accountIdentifier)
                StringArrayField("Phone numbers", values: $draft.phoneNumbers)
                StringArrayField("Instant-message addresses", values: $draft.instantMessageAddresses)
            } header: {
                Text("People / Mail Metadata")
            } footer: {
                Text("For public.email-message items, indexing now also derives real CSPerson authors/To recipients, email headers, HTML content, a creation date, and requests Spotlight priority + summarization processing.")
            }

            Section("Ranking / Ownership Signals") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ranking hint")
                        Spacer()
                        Text("\(draft.rankingHint)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(draft.rankingHint) },
                            set: { draft.rankingHint = Int($0.rounded()) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                }
                Toggle("User created", isOn: $draft.userCreated)
                Toggle("User curated", isOn: $draft.userCurated)
                Toggle("User owned", isOn: $draft.userOwned)
            }

            Section {
                ForEach($draft.customAttributes) { $custom in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Custom Attribute")
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                draft.customAttributes.removeAll { $0.id == custom.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }

                        TextField("Key name", text: $custom.keyName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        StringArrayField("Values", values: $custom.values)
                        Toggle("Searchable", isOn: $custom.searchable)
                        Toggle("Searchable by default", isOn: $custom.searchableByDefault)
                        Toggle("Unique", isOn: $custom.unique)
                        Toggle("Multi-valued", isOn: $custom.multiValued)
                    }
                    .padding(.vertical, 5)
                }

                Button("Add Custom Attribute", systemImage: "plus") {
                    draft.customAttributes.append(SpotlightCustomAttributeConfiguration())
                }
            } header: {
                Text("Custom Spotlight Attributes")
            } footer: {
                Text("Custom keys let us test searchableByDefault directly. Invalid key characters are sanitized when indexing.")
            }

            Section("Semantic Indexing") {
                Picker("Mode", selection: $draft.semanticMode) {
                    ForEach(SpotlightLabSemanticMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                TextField("Entity searchable text", text: $draft.entitySearchText, axis: .vertical)
                    .lineLimit(2...6)
                Stepper("Entity priority: \(draft.entityPriority)", value: $draft.entityPriority, in: 0...1000)

                Text("The lab entity now uses explicit @ComputedProperty(indexingKey:) mappings for displayName and contentDescription, so Associate/Direct modes exercise Apple's native IndexedEntity indexing path rather than only attributeSet metadata.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Look / Sefaria") {
                Picker("Preview mode", selection: $draft.previewMode) {
                    ForEach(SpotlightLabPreviewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                StringArrayField("Query prefixes to strip", values: $draft.queryPrefixesToStrip)

                Text("Diagnostics-only mode never calls Sefaria. It displays this item's current configuration and the raw Spotlight query inside Quick Look.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Item JSON") {
                Button("Copy This Item JSON", systemImage: "doc.on.doc") {
                    copyItemJSON()
                }
                Button("Replace This Item from Clipboard", systemImage: "doc.on.clipboard") {
                    replaceItemFromClipboard()
                }
                Text("Replace accepts either one JSON object or an array and uses the first item. The current editor identity is preserved, so saving updates this row rather than creating a duplicate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current Configuration Snapshot") {
                Text(SpotlightItemLabStore.diagnosticSummary(for: draft))
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }

            Section {
                Button("Save") {
                    save(reindex: false)
                }
                Button("Save & Reindex", systemImage: "arrow.clockwise") {
                    save(reindex: true)
                }
                if !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(draft.experimentLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(reindex: false) }
            }
        }
    }

    private func save(reindex: Bool) {
        draft.uniqueIdentifier = draft.uniqueIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.domainIdentifier = draft.domainIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.uniqueIdentifier.isEmpty {
            draft.uniqueIdentifier = "lab.custom.\(UUID().uuidString.lowercased())"
        }
        onSave(draft, reindex)
        status = reindex ? "Saved and reindex requested" : "Saved"
        DiagnosticLog.record(
            "spotlight.lab.editor.saved",
            details: [
                "identifier": draft.uniqueIdentifier,
                "reindex": String(reindex),
                "semanticMode": draft.semanticMode.rawValue,
                "customCount": String(draft.customAttributes.count)
            ]
        )
        if !reindex {
            dismiss()
        }
    }

    private func copyItemJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(draft),
              let string = String(data: data, encoding: .utf8) else {
            status = "Could not encode item JSON"
            return
        }
        UIPasteboard.general.string = string
        status = "This item JSON copied"
    }

    private func replaceItemFromClipboard() {
        guard let string = UIPasteboard.general.string,
              let data = string.data(using: .utf8) else {
            status = "Clipboard is empty"
            return
        }

        let replacement: SpotlightLabItemConfiguration?
        if let item = try? JSONDecoder().decode(SpotlightLabItemConfiguration.self, from: data) {
            replacement = item
        } else if let items = try? JSONDecoder().decode([SpotlightLabItemConfiguration].self, from: data) {
            replacement = items.first
        } else {
            replacement = nil
        }

        guard var replacement else {
            status = "Clipboard does not contain a valid Spotlight item"
            return
        }
        replacement.id = draft.id
        draft = replacement
        status = "Item loaded from clipboard — Save or Save & Reindex"
    }
}

private struct StringArrayField: View {
    let title: String
    @Binding var values: [String]

    init(_ title: String, values: Binding<[String]>) {
        self.title = title
        _values = values
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("One value per line", text: binding, axis: .vertical)
                .lineLimit(2...7)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { values.joined(separator: "\n") },
            set: { newValue in
                values = newValue
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
