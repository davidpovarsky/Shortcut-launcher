import AppIntents

struct LauncherControlConfigurationIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Launcher Control"
    static let description = IntentDescription("Choose which launcher this Control Center control activates.")

    @Parameter(title: "Launcher")
    var launcher: LauncherEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Launcher \(\.$launcher)")
    }

    init() {}
}
