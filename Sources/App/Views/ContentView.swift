import SwiftUI

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case controls
    case widgets
    case notifications
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .controls: "Controls"
        case .widgets: "Widgets"
        case .notifications: "Notifications"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .controls: "switch.2"
        case .widgets: "square.grid.2x2"
        case .notifications: "bell.badge"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(LauncherLibraryModel.self) private var library
    @State private var selection: WorkspaceSection? = .controls

    private var activeSection: WorkspaceSection {
        selection ?? .controls
    }

    var body: some View {
        NavigationSplitView {
            List(WorkspaceSection.allCases, selection: $selection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbolName)
                }
                .tag(section)
            }
            .navigationTitle("Dav Launcher")
        } detail: {
            NavigationStack {
                rootView(for: activeSection)
            }
            // Recreate the detail navigation stack whenever the sidebar tab changes.
            // This both refreshes the selected tab's root view and discards any child
            // destination that was pushed by the previously selected tab.
            .id(activeSection)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { oldValue, newValue in
            DiagnosticLog.record(
                "workspace.section.changed",
                details: [
                    "from": oldValue?.rawValue ?? "nil",
                    "to": newValue?.rawValue ?? "controls"
                ]
            )
        }
        .task {
            await library.requestNotificationAuthorizationIfNeeded()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { library.lastErrorMessage != nil },
                set: { if !$0 { library.lastErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.lastErrorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private func rootView(for section: WorkspaceSection) -> some View {
        switch section {
        case .controls:
            ControlsView()
        case .widgets:
            WidgetsView()
        case .notifications:
            NotificationsView()
        case .settings:
            SettingsView(embedded: true)
        }
    }
}
