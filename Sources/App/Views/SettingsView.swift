import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(LauncherLibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(SefariaSpotlightLab.enabledKey, store: AppEnvironment.sharedDefaults)
    private var sefariaSpotlightEnabled = true

    @State private var sefariaIndexStatus = "Not checked"
    @State private var sefariaLastQuery = "none"
    @State private var sefariaLastPreviewStatus = "never previewed"
    @State private var sefariaLastResultCount = "0"
    @State private var sefariaLastError = "none"
    @State private var sefariaAPITestStatus = "Not run"
    @State private var configuredSpotlightItems = "0"

    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        Group {
            if embedded {
                settingsForm
            } else {
                NavigationStack {
                    settingsForm
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            }
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Language") {
                Picker("App Language", selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.titleKey).tag(language.rawValue)
                    }
                }
                Text("Dav Launcher supports English and Hebrew. You can also leave it on Follow System.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                LabeledContent("Authorization", value: notificationStatusText)
                if library.notificationAuthorizationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task { await library.requestNotificationAuthorization() }
                    }
                } else if library.notificationAuthorizationStatus == .denied {
                    Button("Open Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            }

            Section("Spotlight + Sefaria Lab") {
                Toggle("Enable Spotlight Sefaria items", isOn: $sefariaSpotlightEnabled)
                    .onChange(of: sefariaSpotlightEnabled) { _, enabled in
                        SefariaSpotlightLab.isEnabled = enabled
                        if enabled {
                            SefariaSpotlightLab.indexItems(reason: "settings.toggleEnabled")
                        } else {
                            SefariaSpotlightLab.removeItems(reason: "settings.toggleDisabled")
                        }
                        DiagnosticLog.record(
                            "settings.spotlightSefaria.toggle",
                            details: ["enabled": String(enabled)]
                        )
                        refreshSefariaDiagnostics()
                    }

                NavigationLink {
                    SpotlightItemLabView()
                } label: {
                    LabeledContent("Spotlight Item Lab", value: "\(configuredSpotlightItems) items")
                }

                Text("Open Spotlight Item Lab to create, duplicate and edit searchable items at runtime. You can change titles, keywords, text content, mail metadata, ranking signals, custom searchableByDefault keys, IndexedEntity modes and Quick Look behavior, then reindex without rebuilding the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Reindex Spotlight Items") {
                    SefariaSpotlightLab.indexItems(reason: "settings.manualReindex")
                    sefariaIndexStatus = "Index request sent"
                }

                Button("Remove Spotlight Items", role: .destructive) {
                    SefariaSpotlightLab.removeItems(reason: "settings.manualRemove")
                    sefariaIndexStatus = "Remove request sent"
                }

                Button("Test Sefaria API") {
                    sefariaAPITestStatus = "Loading…"
                    DiagnosticLog.record("settings.spotlightSefaria.apiTest.started")
                    Task {
                        do {
                            let payload = try await SefariaSpotlightAPI.loadPreview(
                                identifier: SefariaSpotlightLab.generalSearchIdentifier,
                                rawQuery: "ספריא משה רבנו"
                            )
                            await MainActor.run {
                                sefariaAPITestStatus = "OK — \(payload.resultCount) results, showing \(payload.items.count)"
                                DiagnosticLog.record(
                                    "settings.spotlightSefaria.apiTest.completed",
                                    details: [
                                        "resultCount": String(payload.resultCount),
                                        "shownCount": String(payload.items.count)
                                    ]
                                )
                                DiagnosticLog.syncSharedLogToDocuments()
                            }
                        } catch {
                            await MainActor.run {
                                sefariaAPITestStatus = "Error — \(error.localizedDescription)"
                                DiagnosticLog.record(
                                    "settings.spotlightSefaria.apiTest.failed",
                                    details: ["error": String(describing: error)]
                                )
                                DiagnosticLog.syncSharedLogToDocuments()
                            }
                        }
                    }
                }

                Button("Refresh Sefaria Diagnostics") {
                    refreshSefariaDiagnostics()
                    DiagnosticLog.syncSharedLogToDocuments()
                }

                LabeledContent("Index", value: sefariaIndexStatus)
                LabeledContent("API test", value: sefariaAPITestStatus)
                LabeledContent("Configured items", value: configuredSpotlightItems)
                LabeledContent("Last Spotlight query", value: sefariaLastQuery)
                LabeledContent("Last preview", value: sefariaLastPreviewStatus)
                LabeledContent("Last result count", value: sefariaLastResultCount)

                if sefariaLastError != "none" {
                    Text("Last preview error: \(sefariaLastError)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                Text("For fast diagnosis, use Spotlight Item Lab → Experiment Matrix. It creates eight labeled variants that place the same token in different Spotlight fields and semantic-indexing paths, then indexes them immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                LabeledContent(
                    "App Group Container",
                    value: AppEnvironment.sharedContainerURL == nil ? "MISSING" : "Available"
                )
                .foregroundStyle(AppEnvironment.sharedContainerURL == nil ? .red : .primary)

                LabeledContent("Effective App Group", value: AppEnvironment.appGroupID)
                LabeledContent("Configured App Group", value: AppEnvironment.configuredAppGroupID)
                LabeledContent("Resolution", value: AppEnvironment.appGroupResolutionDescription)

                if let teamIdentifier = AppEnvironment.sideStoreTeamIdentifier {
                    LabeledContent("SideStore Team", value: teamIdentifier)
                }

                Text("Candidates: \(AppEnvironment.appGroupCandidates.joined(separator: ", "))")
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)

                if let path = AppEnvironment.sharedContainerURL?.path {
                    Text(path)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text("The app and its extensions cannot share profiles or extension logs when this container is missing. The SideStore-ready IPA embeds the App Group entitlement so SideStore can provision it, and the app also checks SideStore's Team-ID-suffixed group name.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Files log: \(DiagnosticLog.filesLocationDescription)")
                    .font(.footnote)
                    .textSelection(.enabled)

                Text("After testing a Control Center button or Spotlight Quick Look preview, reopen Dav Launcher or tap Sync Log to Files. Extension events are written to the App Group first, then mirrored into the app's Documents folder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Sync Log to Files") {
                    DiagnosticLog.recordEnvironment("settings.manualLogSync")
                    DiagnosticLog.syncSharedLogToDocuments()
                }

                Button("Clear Diagnostic Log", role: .destructive) {
                    DiagnosticLog.clear()
                    DiagnosticLog.recordEnvironment("settings.logCleared")
                    DiagnosticLog.syncSharedLogToDocuments()
                }
            }

            Section("Shortcuts Callback") {
                Text("At the end of your Shortcut, add Set Launcher State or Reset Launcher. The action can return the Control Center control to Idle or show Success or Error.")
            }

            Section("Direct Widget") {
                Text("The Dav Direct Launcher widget supports multiple SystemShortcut buttons and all Home Screen system widget sizes available to this iOS/iPadOS 27 build.")
            }

            Section("Shared Container") {
                LabeledContent("App Group", value: AppEnvironment.appGroupID)
                Text("The app, Control Center control, widgets and Sefaria Quick Look extension share diagnostics, Spotlight Lab configuration and state through this App Group.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task {
            DiagnosticLog.syncSharedLogToDocuments()
            DiagnosticLog.recordEnvironment("settings.opened")
            SefariaSpotlightLab.ensureIndexedIfEnabled(reason: "settings.opened")
            refreshSefariaDiagnostics()
            DiagnosticLog.syncSharedLogToDocuments()
            await library.refreshNotificationAuthorizationStatus()
        }
    }

    private func refreshSefariaDiagnostics() {
        let snapshot = SefariaSpotlightLab.diagnosticsSnapshot()
        sefariaIndexStatus = snapshot["indexStatus"] ?? "unknown"
        sefariaLastQuery = snapshot["lastQuery"] ?? "none"
        sefariaLastPreviewStatus = snapshot["lastStatus"] ?? "unknown"
        sefariaLastResultCount = snapshot["lastResultCount"] ?? "0"
        sefariaLastError = snapshot["lastError"] ?? "none"
        configuredSpotlightItems = snapshot["configuredItems"] ?? "0"
    }

    private var notificationStatusText: String {
        switch library.notificationAuthorizationStatus {
        case .notDetermined: String(localized: "Not requested")
        case .denied: String(localized: "Denied")
        case .authorized: String(localized: "Allowed")
        case .provisional: String(localized: "Provisional")
        case .ephemeral: String(localized: "Ephemeral")
        @unknown default: String(localized: "Unknown")
        }
    }
}
