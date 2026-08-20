import AppIntents

extension LauncherState: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Launcher state"

    static let caseDisplayRepresentations: [LauncherState: DisplayRepresentation] = [
        .idle: "Idle",
        .active: "Active",
        .success: "Success",
        .failure: "Error"
    ]
}
