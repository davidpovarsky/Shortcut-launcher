import SwiftUI

struct LauncherEditorView: View {
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
                Section("Control Profile") {
                    TextField("Name", text: $draft.name)
                    Text("This profile controls the Control Center icon, color and persistent state. Notifications are edited separately in the Notifications section.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VisualStyleEditor(title: "Idle appearance", style: $draft.appearance.idle)
                VisualStyleEditor(title: "Active appearance", style: $draft.appearance.active)
                VisualStyleEditor(title: "Success appearance", style: $draft.appearance.success)
                VisualStyleEditor(title: "Error appearance", style: $draft.appearance.failure)

                Section("Preview") {
                    LauncherStatePreview(profile: draft)
                }
            }
            .navigationTitle("Edit Control")
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
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct VisualStyleEditor: View {
    let title: LocalizedStringKey
    @Binding var style: LauncherVisualStyle

    private let symbols = [
        "bolt", "bolt.fill", "play.fill", "stop.fill", "pause.fill",
        "book.closed", "book.fill", "lightbulb", "lightbulb.fill",
        "house", "house.fill", "lock", "lock.open", "wifi",
        "antenna.radiowaves.left.and.right", "speaker.wave.2.fill",
        "moon.fill", "sun.max.fill", "checkmark.circle.fill",
        "xmark.circle.fill", "exclamationmark.triangle.fill", "hourglass",
        "sparkles", "music.note", "headphones", "display", "airplayvideo",
        "tv", "gamecontroller.fill", "car.fill", "figure.walk", "bed.double.fill"
    ]

    var body: some View {
        Section {
            TextField("Status title", text: $style.title)
            HStack {
                TextField("SF Symbol", text: $style.symbolName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Image(systemName: style.symbolName)
                    .font(.title2)
                    .foregroundStyle(style.tint.color)
                    .frame(width: 36)
            }
            Picker("Symbol preset", selection: $style.symbolName) {
                ForEach(symbols, id: \.self) { symbol in
                    Label(symbol, systemImage: symbol).tag(symbol)
                }
            }
            Picker("Color", selection: $style.tint) {
                ForEach(LauncherTint.allCases, id: \.self) { tint in
                    Label(tint.rawValue.capitalized, systemImage: "circle.fill")
                        .foregroundStyle(tint.color)
                        .tag(tint)
                }
            }
        } header: {
            Text(title)
        }
    }
}

private struct LauncherStatePreview: View {
    let profile: LauncherProfile

    var body: some View {
        HStack(spacing: 12) {
            ForEach(LauncherState.allCases, id: \.self) { state in
                let style = profile.appearance.style(for: state)
                VStack(spacing: 6) {
                    Image(systemName: style.symbolName)
                        .font(.title2)
                        .foregroundStyle(style.tint.color)
                    Text(LocalizedStringKey(state.defaultTitle))
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}
