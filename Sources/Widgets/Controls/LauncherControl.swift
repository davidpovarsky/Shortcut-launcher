import AppIntents
import SwiftUI
import WidgetKit

struct LauncherControlValue: Sendable {
    var launcher: LauncherEntity
    var isConfigured: Bool
    var title: String
    var status: String
    var symbolName: String
    var tint: LauncherTint
}

struct LauncherControlValueProvider: AppIntentControlValueProvider {
    func previewValue(configuration: LauncherControlConfigurationIntent) -> LauncherControlValue {
        if let launcher = configuration.launcher,
           let profile = SharedLauncherStore.profile(id: launcher.id) {
            return Self.value(for: profile)
        }

        let profile = LauncherProfile.sampleReading()
        return Self.value(for: profile, isConfigured: configuration.launcher != nil)
    }

    func currentValue(configuration: LauncherControlConfigurationIntent) async throws -> LauncherControlValue {
        guard let launcher = configuration.launcher,
              let profile = SharedLauncherStore.profile(id: launcher.id) else {
            let placeholder = LauncherProfile.sampleReading()
            return Self.value(for: placeholder, isConfigured: false)
        }
        return Self.value(for: profile)
    }

    private static func value(for profile: LauncherProfile, isConfigured: Bool = true) -> LauncherControlValue {
        let state = profile.resolvedState()
        let style = profile.appearance.style(for: state)
        return LauncherControlValue(
            launcher: LauncherEntity(profile: profile),
            isConfigured: isConfigured,
            title: profile.name,
            status: style.title,
            symbolName: style.symbolName,
            tint: style.tint
        )
    }
}

struct LauncherControl: ControlWidget {
    static let kind = LauncherReloadService.controlKind

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: LauncherControlValueProvider()
        ) { value in
            ControlWidgetButton(
                action: ActivateLauncherIntent(launcher: value.launcher)
            ) {
                Label(value.status, systemImage: value.symbolName)
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : value.status,
                    systemImage: isPerforming ? "hourglass" : value.symbolName
                )
            }
            .tint(value.tint.color)
            .disabled(!value.isConfigured)
        }
        .displayName("Dav Launcher")
        .description("Run a configurable launcher and reflect its persistent state.")
        .promptsForUserConfiguration()
    }
}
