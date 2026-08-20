import SwiftUI

struct ContentView: View {
    @Environment(LauncherLibraryModel.self) private var library
    @State private var editorProfile: LauncherProfile?
    @State private var showsSettings = false

    var body: some View {
        @Bindable var library = library

        NavigationSplitView {
            List(selection: $library.selectedID) {
                Section("Launchers") {
                    ForEach(library.profiles) { profile in
                        LauncherRowView(profile: profile)
                            .tag(profile.id)
                            .contextMenu {
                                Button("Duplicate") {
                                    library.duplicate(profile)
                                }
                                Button("Delete", role: .destructive) {
                                    library.delete(profile)
                                }
                            }
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            library.delete(library.profiles[offset])
                        }
                    }
                }
            }
            .navigationTitle("Dav Launcher")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorProfile = LauncherProfile.makeNew()
                    } label: {
                        Label("New Launcher", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showsSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        } detail: {
            if let profile = library.selectedProfile {
                LauncherDetailView(
                    profile: profile,
                    onEdit: { editorProfile = profile }
                )
                .id(profile.id)
            } else {
                ContentUnavailableView(
                    "No Launcher Selected",
                    systemImage: "square.grid.2x2",
                    description: Text("Create a launcher to start building Control Center and widget actions.")
                )
            }
        }
        .sheet(item: $editorProfile) { profile in
            LauncherEditorView(profile: profile) { saved in
                library.save(saved)
                editorProfile = nil
            } onCancel: {
                editorProfile = nil
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
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
}

private extension LauncherProfile {
    static func makeNew() -> LauncherProfile {
        let id = UUID()
        return LauncherProfile(
            id: id,
            name: "New Launcher",
            appearance: LauncherAppearance(
                idle: .init(title: "Ready", symbolName: "bolt", tint: .gray),
                active: .init(title: "Running", symbolName: "bolt.fill", tint: .blue),
                success: .init(title: "Done", symbolName: "checkmark.circle.fill", tint: .green),
                failure: .init(title: "Error", symbolName: "exclamationmark.triangle.fill", tint: .red)
            ),
            notification: LauncherNotification(
                automationToken: "DAV:\(id.uuidString.prefix(8).uppercased())"
            )
        )
    }
}
