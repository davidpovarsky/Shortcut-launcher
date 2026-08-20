import AppIntents
import SwiftUI
import WidgetKit

struct DirectLauncherWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dav Direct Launcher"
    static let description = IntentDescription("Create a direct launcher widget with up to eight actions.")

    @Parameter(title: "Widget Style")
    var widgetStyle: LauncherWidgetStyle?

    @Parameter(title: "Action 1")
    var shortcut1: SystemShortcut?

    @Parameter(title: "Action 1 Appearance")
    var launcher1: LauncherEntity?

    @Parameter(title: "Action 2")
    var shortcut2: SystemShortcut?

    @Parameter(title: "Action 2 Appearance")
    var launcher2: LauncherEntity?

    @Parameter(title: "Action 3")
    var shortcut3: SystemShortcut?

    @Parameter(title: "Action 3 Appearance")
    var launcher3: LauncherEntity?

    @Parameter(title: "Action 4")
    var shortcut4: SystemShortcut?

    @Parameter(title: "Action 4 Appearance")
    var launcher4: LauncherEntity?

    @Parameter(title: "Action 5")
    var shortcut5: SystemShortcut?

    @Parameter(title: "Action 5 Appearance")
    var launcher5: LauncherEntity?

    @Parameter(title: "Action 6")
    var shortcut6: SystemShortcut?

    @Parameter(title: "Action 6 Appearance")
    var launcher6: LauncherEntity?

    @Parameter(title: "Action 7")
    var shortcut7: SystemShortcut?

    @Parameter(title: "Action 7 Appearance")
    var launcher7: LauncherEntity?

    @Parameter(title: "Action 8")
    var shortcut8: SystemShortcut?

    @Parameter(title: "Action 8 Appearance")
    var launcher8: LauncherEntity?
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
        Timeline(
            entries: [DirectLauncherEntry(date: .now, configuration: configuration)],
            policy: .never
        )
    }
}

private struct LauncherWidgetSlot {
    let shortcut: SystemShortcut
    let launcher: LauncherEntity?
    let index: Int
}

struct DirectLauncherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DirectLauncherEntry

    var body: some View {
        let style = entry.configuration?.widgetStyle ?? .glass
        let slots = configuredSlots.prefix(maxButtons)

        Group {
            if slots.isEmpty {
                configurationPlaceholder
            } else {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                        launcherButton(slot: slot, widgetStyle: style)
                    }
                }
                .padding(contentPadding)
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground(style)
        }
    }

    private var configurationPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
            Text("Configure Launcher")
                .font(.headline)
            Text("Edit the widget and choose Action 1.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func launcherButton(
        slot: LauncherWidgetSlot,
        widgetStyle: LauncherWidgetStyle
    ) -> some View {
        let profile = slot.launcher.flatMap { SharedLauncherStore.profile(id: $0.id) }
        let visual = profile?.resolvedStyle()
        let tint = visual?.tint.color ?? fallbackTint(slot.index)
        let symbol = visual?.symbolName ?? fallbackSymbol(slot.index)

        return Button(intent: RunSystemShortcutIntent(shortcut: slot.shortcut)) {
            buttonLabel(
                shortcut: slot.shortcut,
                profile: profile,
                symbol: symbol,
                tint: tint,
                widgetStyle: widgetStyle
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func buttonLabel(
        shortcut: SystemShortcut,
        profile: LauncherProfile?,
        symbol: String,
        tint: Color,
        widgetStyle: LauncherWidgetStyle
    ) -> some View {
        switch widgetStyle {
        case .glass:
            VStack(spacing: compactSpacing) {
                Image(systemName: symbol)
                    .font(iconFont)
                buttonTitle(shortcut: shortcut, profile: profile)
                    .font(titleFont)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(
                tint.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

        case .cards:
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(iconFont)
                buttonTitle(shortcut: shortcut, profile: profile)
                    .font(titleFont)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(
                Color.primary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )

        case .minimal:
            VStack(spacing: compactSpacing) {
                Image(systemName: symbol)
                    .font(iconFont)
                buttonTitle(shortcut: shortcut, profile: profile)
                    .font(titleFont)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(5)

        case .vibrant:
            VStack(spacing: compactSpacing) {
                Image(systemName: symbol)
                    .font(iconFont)
                buttonTitle(shortcut: shortcut, profile: profile)
                    .font(titleFont.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(
                tint.gradient,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    @ViewBuilder
    private func buttonTitle(
        shortcut: SystemShortcut,
        profile: LauncherProfile?
    ) -> some View {
        if let profile {
            let visual = profile.resolvedStyle()
            Text(visual.title.isEmpty ? profile.name : visual.title)
                .multilineTextAlignment(.center)
        } else {
            Text(shortcut.displayRepresentation.title)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func widgetBackground(_ style: LauncherWidgetStyle) -> some View {
        switch style {
        case .glass:
            LinearGradient(
                colors: [Color.primary.opacity(0.07), Color.primary.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cards:
            Color.secondary.opacity(0.08)
        case .minimal:
            Color.clear
        case .vibrant:
            LinearGradient(
                colors: [Color.indigo.opacity(0.22), Color.blue.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var configuredSlots: [LauncherWidgetSlot] {
        guard let configuration = entry.configuration else { return [] }

        var result: [LauncherWidgetSlot] = []
        if let shortcut = configuration.shortcut1 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher1, index: 0))
        }
        if let shortcut = configuration.shortcut2 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher2, index: 1))
        }
        if let shortcut = configuration.shortcut3 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher3, index: 2))
        }
        if let shortcut = configuration.shortcut4 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher4, index: 3))
        }
        if let shortcut = configuration.shortcut5 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher5, index: 4))
        }
        if let shortcut = configuration.shortcut6 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher6, index: 5))
        }
        if let shortcut = configuration.shortcut7 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher7, index: 6))
        }
        if let shortcut = configuration.shortcut8 {
            result.append(.init(shortcut: shortcut, launcher: configuration.launcher8, index: 7))
        }
        return result
    }

    private var maxButtons: Int {
        switch family {
        case .systemSmall:
            2
        case .systemMedium:
            4
        case .systemLarge:
            6
        case .systemExtraLarge, .systemExtraLargePortrait:
            8
        default:
            4
        }
    }

    private var gridColumns: [GridItem] {
        let count: Int
        switch family {
        case .systemSmall:
            count = 1
        case .systemMedium, .systemLarge, .systemExtraLargePortrait:
            count = 2
        case .systemExtraLarge:
            count = 4
        default:
            count = 2
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var contentPadding: CGFloat {
        family == .systemSmall ? 10 : 12
    }

    private var compactSpacing: CGFloat {
        family == .systemSmall ? 5 : 7
    }

    private var iconFont: Font {
        switch family {
        case .systemSmall:
            .title3
        case .systemMedium:
            .title2
        default:
            .title
        }
    }

    private var titleFont: Font {
        family == .systemSmall ? .caption2 : .caption
    }

    private func fallbackSymbol(_ index: Int) -> String {
        ["bolt.fill", "play.fill", "house.fill", "music.note", "lightbulb.fill", "book.fill", "sparkles", "gearshape.fill"][index % 8]
    }

    private func fallbackTint(_ index: Int) -> Color {
        [.blue, .orange, .green, .purple, .yellow, .indigo, .pink, .teal][index % 8]
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
        .description("Launch up to eight apps, shortcuts or system actions directly from one customizable widget.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .systemExtraLargePortrait
        ])
    }
}
