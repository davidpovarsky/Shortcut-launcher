import SwiftUI
import UIKit
import UserNotifications

struct NotificationsView: View {
    @Environment(LauncherLibraryModel.self) private var library
    @Environment(\.openURL) private var openURL
    @State private var editorProfile: LauncherProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                authorizationCard

                if library.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Notification Profiles",
                        systemImage: "bell.slash",
                        description: Text("Create a control profile first. Every profile can have its own local notification and automation token.")
                    )
                } else {
                    VStack(spacing: 14) {
                        ForEach(library.profiles) { profile in
                            NotificationProfileCard(
                                profile: profile,
                                onEdit: { editorProfile = profile },
                                onTest: {
                                    Task { await library.sendTestNotification(for: profile) }
                                }
                            )
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use the visible automation token as the stable keyword in the Shortcuts Notification Automation trigger.")
                        Text("For example: [DAV:READING]. You can freely change the human-readable title and body without breaking the automation.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Shortcuts Notification Automation", systemImage: "arrow.triangle.branch")
                }
            }
            .padding(24)
        }
        .navigationTitle("Notifications")
        .task {
            await library.refreshNotificationAuthorizationStatus()
        }
        .sheet(item: $editorProfile) { profile in
            NotificationEditorView(profile: profile) { saved in
                library.save(saved)
                editorProfile = nil
            } onCancel: {
                editorProfile = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications", systemImage: "bell.badge")
                .font(.largeTitle.bold())
            Text("Configure local notifications separately from Control Center appearance and widgets.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var authorizationCard: some View {
        GroupBox {
            HStack(spacing: 16) {
                Image(systemName: authorizationSymbol)
                    .font(.title)
                    .foregroundStyle(authorizationColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("System Permission")
                        .font(.headline)
                    Text(authorizationText)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if library.notificationAuthorizationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task { await library.requestNotificationAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                } else if library.notificationAuthorizationStatus == .denied {
                    Button("Open Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var authorizationText: LocalizedStringKey {
        switch library.notificationAuthorizationStatus {
        case .notDetermined: "Permission has not been requested yet."
        case .denied: "Notifications are blocked. Control Center triggers will show Error until permission is enabled."
        case .authorized: "Notifications are allowed."
        case .provisional: "Notifications are provisionally allowed."
        case .ephemeral: "Notifications are temporarily allowed."
        @unknown default: "Notification permission status is unknown."
        }
    }

    private var authorizationSymbol: String {
        switch library.notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        default: "bell.badge"
        }
    }

    private var authorizationColor: Color {
        switch library.notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .red
        default: .orange
        }
    }
}

private struct NotificationProfileCard: View {
    let profile: LauncherProfile
    let onEdit: () -> Void
    let onTest: () -> Void

    var body: some View {
        let notification = profile.notification

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(.headline)
                        Text(LocalizedStringKey(notification.isEnabled ? "Enabled" : "Disabled"))
                            .font(.caption)
                            .foregroundStyle(notification.isEnabled ? .green : .secondary)
                    }
                    Spacer()
                    Button("Edit", action: onEdit)
                }

                Divider()

                LabeledContent("Title", value: notification.title.isEmpty ? profile.name : notification.title)
                LabeledContent("Body", value: notification.renderedBody)
                LabeledContent("Token", value: notification.automationToken)

                Button(action: onTest) {
                    Label("Send Test Notification", systemImage: "bell.badge")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!notification.isEnabled)
            }
        }
    }
}

private struct NotificationEditorView: View {
    @State private var draft: LauncherProfile
    let onSave: (LauncherProfile) -> Void
    let onCancel: () -> Void

    init(
        profile: LauncherProfile,
        onSave: @escaping (LauncherProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notification") {
                    Toggle("Send local notification", isOn: $draft.notification.isEnabled)
                    TextField("Notification title", text: $draft.notification.title)
                    TextField("Subtitle", text: $draft.notification.subtitle)
                    TextField("Body", text: $draft.notification.body, axis: .vertical)
                        .lineLimit(2...6)
                    Toggle("Play sound", isOn: $draft.notification.playsSound)
                }

                Section("Automation Routing") {
                    Toggle("Include automation token", isOn: $draft.notification.includesAutomationToken)
                    TextField("Automation token", text: $draft.notification.automationToken)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .disabled(!draft.notification.includesAutomationToken)
                    Text("Keep this token stable and use it as the keyword in your Shortcuts Notification Automation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Preview") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.notification.title.isEmpty ? draft.name : draft.notification.title)
                            .font(.headline)
                        if !draft.notification.subtitle.isEmpty {
                            Text(draft.notification.subtitle)
                                .font(.subheadline)
                        }
                        Text(draft.notification.renderedBody)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Notification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var copy = draft
                        copy.updatedAt = .now
                        onSave(copy)
                    }
                }
            }
        }
    }
}
