import SwiftUI

struct ControlsView: View {
    @Environment(LauncherLibraryModel.self) private var library
    @State private var editorProfile: LauncherProfile?

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader

                if library.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Controls Yet",
                        systemImage: "switch.2",
                        description: Text("Create a control profile, then choose it when editing the Dav Launcher control in Control Center.")
                    )
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(library.profiles) { profile in
                            ControlProfileCard(
                                profile: profile,
                                onEdit: { editorProfile = profile },
                                onDuplicate: { library.duplicate(profile) },
                                onDelete: { library.delete(profile) },
                                onSetState: { state in library.setState(state, for: profile) }
                            )
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Add the Dav Launcher control from Control Center.", systemImage: "1.circle.fill")
                        Label("Edit the control and choose one of the control profiles above.", systemImage: "2.circle.fill")
                        Label("A tap changes the persistent icon and color, then sends the profile notification trigger.", systemImage: "3.circle.fill")
                        Label("Your Shortcut can call Set Launcher State or Reset Launcher to change it back.", systemImage: "4.circle.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Control Center Setup", systemImage: "switch.2")
                }
            }
            .padding(24)
        }
        .navigationTitle("Controls")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorProfile = .makeNew()
                } label: {
                    Label("New Control", systemImage: "plus")
                }
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
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Control Center", systemImage: "switch.2")
                .font(.largeTitle.bold())
            Text("Create reusable control profiles with a different icon, color and label for Idle, Active, Success and Error.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ControlProfileCard: View {
    let profile: LauncherProfile
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onSetState: (LauncherState) -> Void

    var body: some View {
        let state = profile.resolvedState()
        let style = profile.appearance.style(for: state)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(style.tint.color.opacity(0.16))
                    Image(systemName: style.symbolName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(style.tint.color)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.title3.bold())
                    Text(style.title)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(state.defaultTitle))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.tint.color)
                }

                Spacer()

                Menu {
                    Button("Edit", action: onEdit)
                    Button("Duplicate", action: onDuplicate)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
            }

            HStack {
                ForEach(LauncherState.allCases, id: \.self) { item in
                    Button {
                        onSetState(item)
                    } label: {
                        let itemStyle = profile.appearance.style(for: item)
                        Image(systemName: itemStyle.symbolName)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(item == state ? itemStyleTint(profile, item) : .gray)
                    .accessibilityLabel(Text(LocalizedStringKey(item.defaultTitle)))
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func itemStyleTint(_ profile: LauncherProfile, _ state: LauncherState) -> Color {
        profile.appearance.style(for: state).tint.color
    }
}
