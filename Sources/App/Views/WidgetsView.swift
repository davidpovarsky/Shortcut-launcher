import SwiftUI

struct WidgetsView: View {
    @Environment(LauncherLibraryModel.self) private var library

    private let columns = [
        GridItem(.adaptive(minimum: 210), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Small: up to 2 actions", systemImage: "square")
                        Label("Medium: up to 4 actions", systemImage: "rectangle")
                        Label("Large: up to 6 actions", systemImage: "rectangle.portrait")
                        Label("Extra Large: up to 8 actions", systemImage: "rectangle.split.3x3")
                        Label("Extra Large Portrait: up to 8 actions", systemImage: "rectangle.portrait")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Supported Widget Sizes", systemImage: "aspectratio")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Widget Designs")
                        .font(.title2.bold())
                    Text("Choose the style when editing the widget on the Home Screen.")
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(LauncherWidgetStyle.allCases, id: \.self) { style in
                            WidgetStylePreview(
                                style: style,
                                profiles: Array(library.profiles.prefix(4))
                            )
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Add Dav Direct Launcher from the widget gallery.", systemImage: "1.circle.fill")
                        Label("Long-press the widget and choose Edit Widget.", systemImage: "2.circle.fill")
                        Label("Choose a design, then configure Action 1 through Action 8 as needed.", systemImage: "3.circle.fill")
                        Label("Optionally choose an Appearance Profile for each action to reuse its icon, color and state.", systemImage: "4.circle.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Widget Configuration", systemImage: "slider.horizontal.3")
                }

                Text("The iOS 27 SystemShortcut picker is owned by the system, so shortcut/app/system-action selection happens in Edit Widget rather than inside Dav Launcher.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("Widgets")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Widgets", systemImage: "square.grid.2x2")
                .font(.largeTitle.bold())
            Text("Build direct-launch widgets with multiple buttons for apps, App Shortcuts, custom Shortcuts and system actions.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WidgetStylePreview: View {
    let style: LauncherWidgetStyle
    let profiles: [LauncherProfile]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey(style.title), systemImage: style.symbolName)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    let profile = profile(at: index)
                    let visual = profile?.resolvedStyle()
                    previewButton(
                        title: profile?.name ?? "Action",
                        symbol: visual?.symbolName ?? fallbackSymbol(index),
                        tint: visual?.tint.color ?? fallbackColor(index)
                    )
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func previewButton(title: String, symbol: String, tint: Color) -> some View {
        switch style {
        case .glass:
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.caption).lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .cards:
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(title).font(.caption).lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .minimal:
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.caption2).lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 72)

        case .vibrant:
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.caption).lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func profile(at index: Int) -> LauncherProfile? {
        guard profiles.indices.contains(index) else { return nil }
        return profiles[index]
    }

    private func fallbackSymbol(_ index: Int) -> String {
        ["bolt.fill", "play.fill", "house.fill", "music.note"][index % 4]
    }

    private func fallbackColor(_ index: Int) -> Color {
        [.blue, .orange, .green, .purple][index % 4]
    }
}
