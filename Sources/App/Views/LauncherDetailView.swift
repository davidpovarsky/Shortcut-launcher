import SwiftUI

struct LauncherDetailView: View {
    @Environment(LauncherLibraryModel.self) private var library
    let profile: LauncherProfile
    let onEdit: () -> Void

    var body: some View {
        let state = profile.resolvedState()
        let style = profile.appearance.style(for: state)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(style.tint.color.opacity(0.15))
                        Image(systemName: style.symbolName)
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundStyle(style.tint.color)
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(profile.name)
                            .font(.largeTitle.bold())
                        Text(style.title)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("State: \(state.defaultTitle)")
                            .font(.headline)
                    }
                    Spacer()
                }

                GroupBox("State") {
                    HStack {
                        stateButton("Idle", state: .idle, symbol: "circle")
                        stateButton("Active", state: .active, symbol: "bolt.fill")
                        stateButton("Success", state: .success, symbol: "checkmark.circle.fill")
                        stateButton("Error", state: .failure, symbol: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 4)
                }

                GroupBox("Notification Automation") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Enabled", value: profile.notification.isEnabled ? "Yes" : "No")
                        LabeledContent("Title", value: profile.notification.title)
                        LabeledContent("Body", value: profile.notification.renderedBody)
                        LabeledContent("Token", value: profile.notification.automationToken)
                        Button {
                            Task { await library.sendTestNotification(for: profile) }
                        } label: {
                            Label("Send Test Notification", systemImage: "bell.badge")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!profile.notification.isEnabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("How this launcher works") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Control Center: choose this launcher in the configurable Dav Launcher control.", systemImage: "switch.2")
                        Label("The control changes to Active and sends the local notification trigger.", systemImage: "bell")
                        Label("At the end of your Shortcut, run Set Launcher State or Reset Launcher to update the icon and tint.", systemImage: "arrow.uturn.backward")
                        Label("Home Screen widget: configure a System Shortcut for direct launching on iOS/iPadOS 27.", systemImage: "square.grid.2x2")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(28)
        }
        .navigationTitle(profile.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
            }
        }
    }

    private func stateButton(_ title: String, state: LauncherState, symbol: String) -> some View {
        Button {
            library.setState(state, for: profile)
        } label: {
            Label(title, systemImage: symbol)
        }
    }
}
