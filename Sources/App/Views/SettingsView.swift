import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var requestError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    LabeledContent("Authorization", value: statusText)
                    if status == .notDetermined {
                        Button("Allow Notifications") {
                            Task { await requestNotifications() }
                        }
                    } else if status == .denied {
                        Button("Open Settings") {
                            openURL(URL(string: UIApplication.openSettingsURLString)!)
                        }
                    }
                }

                Section("Control Center setup") {
                    Text("Add the Dav Launcher control in Control Center. Long-press it in edit mode and choose one of your launcher profiles.")
                    Text("Pressing the control stores the Active state, refreshes the control appearance, and sends the profile's configured local notification.")
                }

                Section("Shortcuts callback") {
                    Text("At the end of your Shortcut, add Dav Launcher's Set Launcher State or Reset Launcher action. This lets the Shortcut switch the control back to Idle, Success, or Error.")
                }

                Section("Direct launcher widget on iOS/iPadOS 27") {
                    Text("Add the Dav Direct Launcher widget to the Home Screen, edit the widget, choose an Appearance Profile, then choose Action. The system Action picker can select an installed app, App Shortcut, custom Shortcut, or system action.")
                }

                Section("Shared container") {
                    LabeledContent("App Group", value: AppEnvironment.appGroupID)
                    Text("The app and WidgetKit extension share launcher profiles and state through this App Group.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await refreshStatus() }
            .alert("Notification Error", isPresented: Binding(
                get: { requestError != nil },
                set: { if !$0 { requestError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(requestError ?? "Unknown error")
            }
        }
    }

    private var statusText: String {
        switch status {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
    }

    private func refreshStatus() async {
        status = await NotificationService.authorizationStatus()
    }

    private func requestNotifications() async {
        do {
            _ = try await NotificationService.requestAuthorization()
            await refreshStatus()
        } catch {
            requestError = error.localizedDescription
        }
    }
}
