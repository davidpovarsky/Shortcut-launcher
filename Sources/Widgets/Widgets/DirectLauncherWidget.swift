import AppIntents
import SwiftUI
import WidgetKit

struct DirectLauncherWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dav Direct Launcher"
    static let description = IntentDescription("Choose a system action and an optional Dav Launcher appearance profile.")

    @Parameter(title: "Appearance Profile")
    var launcher: LauncherEntity?

    @Parameter(title: "Action")
    var shortcut: SystemShortcut?
}

struct DirectLauncherEntry: TimelineEntry {
    let date: Date
    let configuration: DirectLauncherWidgetIntent?
}

struct DirectLauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DirectLauncherEntry {
        DirectLauncherEntry(date: .now, configuration: nil)
    }

    func snapshot(
        for configuration: DirectLauncherWidgetIntent,
        in context: Context
    ) async -> DirectLauncherEntry {
        DirectLauncherEntry(date: .now, configuration: configuration)
    }

    func timeline(
        for configuration: DirectLauncherWidgetIntent,
        in context: Context
    ) async -> Timeline<DirectLauncherEntry> {
        let entry = DirectLauncherEntry(date: .now, configuration: configuration)
        return Timeline(entries: [entry], policy: .never)
    }
}

struct DirectLauncherWidgetView: View {
    let entry: DirectLauncherEntry

    private var profile: LauncherProfile? {
        guard let id = entry.configuration?.launcher?.id else { return nil }
        return SharedLauncherStore.profile(id: id)
    }

    var body: some View {
        if let configuration = entry.configuration,
           let shortcut = configuration.shortcut {
            let state = profile?.resolvedState() ?? .idle
            let style = profile?.appearance.style(for: state)
                ?? LauncherVisualStyle(title: "Run", symbolName: "play.fill", tint: .blue)
            let title = style.title.isEmpty ? (profile?.name ?? "Run") : style.title

            Button(intent: RunSystemShortcutIntent(shortcut: shortcut)) {
                VStack(spacing: 12) {
                    Image(systemName: style.symbolName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(style.tint.color)
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(shortcut.displayRepresentation.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .containerBackground(for: .widget) {
                style.tint.color.opacity(0.16)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.largeTitle)
                Text("Configure Launcher")
                    .font(.headline)
            }
            .containerBackground(for: .widget) {
                Color.secondary.opacity(0.12)
            }
        }
    }
}

struct DirectLauncherWidget: Widget {
    let kind = LauncherReloadService.directWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DirectLauncherWidgetIntent.self,
            provider: DirectLauncherProvider()
        ) { entry in
            DirectLauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Dav Direct Launcher")
        .description("Directly open an app, App Shortcut, custom Shortcut, or system action on iOS/iPadOS 27.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
