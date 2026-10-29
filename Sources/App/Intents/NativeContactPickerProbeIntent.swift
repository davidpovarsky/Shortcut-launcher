import AppIntents
import Foundation

// MARK: - Native system contact picker probes
//
// Unlike AppEntity, IntentPerson has an explicit contact/email parameter mode.
// These isolated actions determine whether that UI offers search at RUN TIME.
// They do not read, add, or edit Contacts. The sample people are transient
// options with clearly marked .example email addresses.

struct LabDemoPersonOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [IntentPerson] {
        [
            .init(
                identifier: .applicationDefined("dav.lab.demo.daniel"),
                name: .displayName("דניאל כהן (דוגמה)"),
                handle: .init(emailAddress: "daniel-lab@example.com"),
                image: DisplayRepresentation.Image(
                    systemName: "person.crop.circle.fill", isTemplate: true
                )
            ),
            .init(
                identifier: .applicationDefined("dav.lab.demo.sarah"),
                name: .displayName("שרה לוי (דוגמה)"),
                handle: .init(emailAddress: "sarah-lab@example.com"),
                image: DisplayRepresentation.Image(
                    systemName: "person.crop.circle.fill", isTemplate: true
                )
            ),
            .init(
                identifier: .applicationDefined("dav.lab.demo.yosef"),
                name: .displayName("יוסף ישראלי (דוגמה)"),
                handle: .init(emailAddress: "yosef-lab@example.com"),
                image: DisplayRepresentation.Image(
                    systemName: "person.crop.circle.fill", isTemplate: true
                )
            ),
            .init(
                identifier: .applicationDefined("dav.lab.demo.miriam"),
                name: .displayName("מרים ברק (דוגמה)"),
                handle: .init(emailAddress: "miriam-lab@example.com"),
                image: DisplayRepresentation.Image(
                    systemName: "person.crop.circle.fill", isTemplate: true
                )
            ),
            .init(
                identifier: .applicationDefined("dav.lab.demo.rachel"),
                name: .displayName("רחל פרידמן (דוגמה)"),
                handle: .init(emailAddress: "rachel-lab@example.com"),
                image: DisplayRepresentation.Image(
                    systemName: "person.crop.circle.fill", isTemplate: true
                )
            )
        ]
    }
}

/// Baseline: ask the SYSTEM to resolve a real contact during execution.
/// This intentionally has no optionsProvider.
struct LabNativeContactPickerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Native Contact Search"
    static let description = IntentDescription(
        "Test whether the OS opens a searchable native Contacts picker while the Shortcut is running. Does not change contacts."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Contact",
        mode: .contact,
        requestValueDialog: "Search for a contact"
    )
    var person: IntentPerson

    static var parameterSummary: some ParameterSummary {
        Summary("Search contacts for \(\.$person)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: "Selected native person: \(String(describing: person.name))")
    }
}

/// The key experiment: an IntentPerson parameter with application-provided
/// demo options. We want to observe if its native runtime picker shows search
/// and whether it can locate these synthetic people, not just real contacts.
struct LabNativePersonOptionsIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Contact Options Search"
    static let description = IntentDescription(
        "Probe a system Contacts-mode picker with five fictional people provided through DynamicOptionsProvider."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Demo Person",
        mode: .contact,
        requestValueDialog: "Choose a person (demo options)",
        optionsProvider: LabDemoPersonOptionsProvider()
    )
    var person: IntentPerson

    static var parameterSummary: some ParameterSummary {
        Summary("Choose demo contact \(\.$person)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: "Selected contact-mode person: \(String(describing: person.name))")
    }
}

/// Control for the Mail-recipient use case. Email mode may expose a different
/// native runtime selection UI from .contact; test them separately.
struct LabNativeEmailOptionsIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Email Options Search"
    static let description = IntentDescription(
        "Compare the Mail-like native email picker using fictional addresses from DynamicOptionsProvider."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Demo Email Recipient",
        mode: .email,
        requestValueDialog: "Search for an email recipient",
        optionsProvider: LabDemoPersonOptionsProvider()
    )
    var person: IntentPerson

    static var parameterSummary: some ParameterSummary {
        Summary("Choose email recipient \(\.$person)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: "Selected email-mode person: \(String(describing: person.name))")
    }
}
