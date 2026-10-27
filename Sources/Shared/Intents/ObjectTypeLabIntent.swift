import AppIntents
import Foundation
import GeoToolbox
import CoreLocation
import LinkPresentation
import UniformTypeIdentifiers

/// Every picker entry names the *actual* value emitted. A native calendar event,
/// reminder, music-library track, installed app, or PHAsset cannot be fabricated
/// from static demo data, so these cases explicitly report their limitation.
enum ObjectTypeLabKind: String, AppEnum, CaseIterable {
    case richEntity
    case person
    case vcardFile
    case pngImage
    case photoAsset
    case location
    case calendarICS
    case nativeCalendarEvent
    case reminderICS
    case nativeReminder
    case textFile
    case pdfFile
    case audioFile
    case musicFile
    case nativeMusic
    case videoFile
    case articleURL
    case linkMetadata
    case plainURL
    case formattedText
    case plainText
    case installedApp
    case currencyAmount
    case paymentMethod
    case integer
    case decimal
    case date
    case duration
    case boolean
    case personName
    case dateComponents
    case distance
    case systemShortcut
    case audioSearch
    case semanticContent
    case recurrenceRule

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Object type to test"
    }

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .richEntity: "AppEntity - rich rows",
        .person: "IntentPerson - people",
        .vcardFile: "vCard - .vcf files",
        .pngImage: "Images - PNG files",
        .photoAsset: "PHAsset - needs Photos library",
        .location: "PlaceDescriptor - locations",
        .calendarICS: "Calendar - .ics event files",
        .nativeCalendarEvent: "Calendar event - native unavailable",
        .reminderICS: "Reminders - .ics VTODO files",
        .nativeReminder: "Reminder - native unavailable",
        .textFile: "Files - .txt documents",
        .pdfFile: "PDF - documents",
        .audioFile: "Audio - WAV files",
        .musicFile: "Music - WAV demo files",
        .nativeMusic: "Music library item - unavailable",
        .videoFile: "Video - MP4 files",
        .articleURL: "Article - URLs, not WFArticle",
        .linkMetadata: "LinkMetadata - web links",
        .plainURL: "URL - web addresses",
        .formattedText: "AttributedString - rich text",
        .plainText: "String - plain text",
        .installedApp: "Installed app - native unavailable",
        .currencyAmount: "IntentCurrencyAmount - money",
        .paymentMethod: "IntentPaymentMethod - payment",
        .integer: "Int - integers",
        .decimal: "Decimal - decimals",
        .date: "Date - dates",
        .duration: "Duration - time spans",
        .boolean: "Bool - true/false",
        .personName: "PersonNameComponents - names",
        .dateComponents: "DateComponents - partial dates",
        .distance: "Measurement - distances",
        .systemShortcut: "SystemShortcut - existing only",
        .audioSearch: "AudioSearch - Siri request only",
        .semanticContent: "SemanticContentDescriptor - unsupported demo",
        .recurrenceRule: "Calendar recurrence - not event"
    ]

    var isUnavailableNativeType: Bool {
        switch self {
        case .photoAsset, .nativeCalendarEvent, .nativeReminder, .nativeMusic,
             .installedApp, .systemShortcut, .audioSearch, .semanticContent,
             .recurrenceRule:
            return true
        default:
            return false
        }
    }
}

/// One output list type, but ALL elements in a given invocation have the same
/// union case and carry real framework values rather than lookalike AppEntities.
@UnionValue
enum ObjectTypeLabValue {
    case entity(MixedMenuChoiceEntity)
    case person(IntentPerson)
    case file(IntentFile)
    case place(PlaceDescriptor)
    case link(LinkMetadata)
    case url(URL)
    case richText(AttributedString)
    case text(String)
    case integer(Int)
    case decimal(Decimal)
    case date(Date)
    case duration(Duration)
    case boolean(Bool)
    case money(IntentCurrencyAmount)
    case payment(IntentPaymentMethod)
    case personName(PersonNameComponents)
    case dateParts(DateComponents)
    case distance(Measurement<UnitLength>)
}

extension ObjectTypeLabValue {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "System Object Lab Value" }

    static let caseDisplayRepresentations: [Cases: DisplayRepresentation] = [
        .entity: "AppEntity",
        .person: "IntentPerson",
        .file: "IntentFile",
        .place: "PlaceDescriptor",
        .link: "LinkMetadata",
        .url: "URL",
        .richText: "AttributedString",
        .text: "String",
        .integer: "Int",
        .decimal: "Decimal",
        .date: "Date",
        .duration: "Duration",
        .boolean: "Bool",
        .money: "IntentCurrencyAmount",
        .payment: "IntentPaymentMethod",
        .personName: "PersonNameComponents",
        .dateParts: "DateComponents",
        .distance: "Measurement"
    ]
}

/// Set Object Type, run this action, then add Apple's "Choose from List".
/// No input JSON, system prompt, Contacts/Photos/Calendars access, or account
/// mutations. Each type comes with exactly three built-in examples except Bool.
struct ObjectTypeLabIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Generate Object Types"
    static let description = IntentDescription(
        "Return sample objects of the chosen native type to Apple's Choose from List action."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Object Type", default: .richEntity)
    var objectType: ObjectTypeLabKind

    static var parameterSummary: some ParameterSummary {
        Summary("Generate samples of \(\.$objectType)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<[ObjectTypeLabValue]> {
        let values = try await ObjectTypeLabFactory.make(objectType)
        return .result(value: values)
    }
}

enum ObjectTypeLabFactory {
    static func make(_ kind: ObjectTypeLabKind) async throws -> [ObjectTypeLabValue] {
        switch kind {
        case .richEntity:
            let session = UUID().uuidString
            let prototypes: [(String, String, String, String)] = [
                ("הגדרות", "התאמה אישית והעדפות", "gearshape.fill", "#64748B"),
                ("חיפוש", "חיפוש קבצים ומידע", "magnifyingglass", "#8B5CF6"),
                ("מועדפים", "פריטים ששמרת", "star.fill", "#EAB308")
            ]
            let entities = await MainActor.run {
                prototypes.enumerated().map { i, row in
                    let demo = MixedMenuItem(
                        id: "\(i)", type: "rich", title: row.0, subtitle: row.1,
                        icon: row.2, color: row.3, backgroundColor: nil,
                        imageBase64: nil, rawJSON: "{}"
                    )
                    return MixedMenuChoiceEntity(
                        id: "\(session):\(i)", title: row.0, subtitle: row.1,
                        type: "rich", imageData: MixedMenuIconRenderer.image(for: demo)
                    )
                }
            }
            try MixedMenuChoiceStore.save(entities, session: session)
            return entities.map { .entity($0) }

        case .person:
            return [
                person("דניאל כהן", email: "daniel@example.com", id: "daniel", icon: "person.circle.fill"),
                person("שרה לוי", email: "sara@example.com", id: "sara", icon: "person.crop.circle.fill"),
                person("יוסף ישראלי", email: "yosef@example.com", id: "yosef", icon: "person.fill")
            ]

        case .vcardFile:
            return ObjectTypeLabSamples.vCards().map { .file($0) }
        case .pngImage:
            return await ObjectTypeLabSamples.pngImages().map { .file($0) }
        case .location:
            let places = [
                ("ירושלים", 31.778, 35.235),
                ("תל אביב", 32.0853, 34.7818),
                ("חיפה", 32.7940, 34.9896)
            ]
            return places.map { place in
                .place(PlaceDescriptor(
                    representations: [
                        .coordinate(CLLocationCoordinate2D(latitude: place.1, longitude: place.2))
                    ],
                    commonName: place.0
                ))
            }
        case .calendarICS:
            return ObjectTypeLabSamples.calendarEvents().map { .file($0) }
        case .reminderICS:
            return ObjectTypeLabSamples.reminderTasks().map { .file($0) }
        case .textFile:
            return ObjectTypeLabSamples.textFiles().map { .file($0) }
        case .pdfFile:
            return await ObjectTypeLabSamples.pdfFiles().map { .file($0) }
        case .audioFile:
            return ObjectTypeLabSamples.audioSamples(music: false).map { .file($0) }
        case .musicFile:
            return ObjectTypeLabSamples.audioSamples(music: true).map { .file($0) }
        case .videoFile:
            return ObjectTypeLabSamples.videoFiles().map { .file($0) }

        case .articleURL:
            return [
                URL(string: "https://www.apple.com/newsroom/")!,
                URL(string: "https://www.bbc.com/news")!,
                URL(string: "https://en.wikipedia.org/wiki/Apple_Inc.")!
            ].map { .url($0) }
        case .linkMetadata:
            return [
                "https://www.apple.com",
                "https://developer.apple.com",
                "https://www.wikipedia.org"
            ].compactMap(URL.init(string:)).map { .link(LinkMetadata(url: $0)) }
        case .plainURL:
            return [
                "https://www.apple.com",
                "https://www.openstreetmap.org",
                "https://developer.apple.com/documentation/appintents"
            ].compactMap(URL.init(string:)).map { .url($0) }

        case .formattedText:
            return await ObjectTypeLabSamples.formattedTexts().map { .richText($0) }
        case .plainText:
            return [
                "פריט ראשון — טקסט רגיל",
                "פריט שני — תיאור נוסף לבדיקה",
                "Third item — plain String"
            ].map { .text($0) }
        case .currencyAmount:
            return [
                IntentCurrencyAmount(amount: 36, currencyCode: "GBP"),
                IntentCurrencyAmount(amount: 180, currencyCode: "GBP"),
                IntentCurrencyAmount(amount: 250, currencyCode: "USD")
            ].map { .money($0) }
        case .paymentMethod:
            return [
                .payment(IntentPaymentMethod(type: .credit, name: "DEMO Visa", identificationHint: "1234", icon: .init(systemName: "creditcard.fill"))),
                .payment(IntentPaymentMethod(type: .debit, name: "DEMO Debit", identificationHint: "5678", icon: .init(systemName: "creditcard"))),
                .payment(IntentPaymentMethod(type: .applePay, name: "DEMO Apple Pay", identificationHint: nil, icon: .init(systemName: "wallet.pass.fill")))
            ]
        case .integer:
            return [1, 42, 2027].map { .integer($0) }
        case .decimal:
            return [Decimal(string: "3.14")!, Decimal(string: "24.99")!, Decimal(string: "125.50")!]
                .map { .decimal($0) }
        case .date:
            let epoch = Date(timeIntervalSince1970: 1_800_000_000)
            return [epoch, epoch.addingTimeInterval(86_400), epoch.addingTimeInterval(604_800)]
                .map { .date($0) }
        case .duration:
            return [Duration.seconds(30), .minutes(5), .hours(2)].map { .duration($0) }
        case .boolean:
            return [.boolean(true), .boolean(false)]
        case .personName:
            return ["Daniel Cohen", "Sarah Levy", "Yosef Israeli"].map { name in
                var components = PersonNameComponents()
                let parts = name.split(separator: " ")
                components.givenName = parts.first.map(String.init)
                components.familyName = parts.last.map(String.init)
                return .personName(components)
            }
        case .dateComponents:
            return [
                DateComponents(year: 2027, month: 1, day: 1),
                DateComponents(year: 2027, month: 4, day: 15),
                DateComponents(year: 2027, month: 10, day: 27)
            ].map { .dateParts($0) }
        case .distance:
            return [
                Measurement(value: 1.5, unit: UnitLength.kilometers),
                Measurement(value: 250, unit: UnitLength.meters),
                Measurement(value: 12, unit: UnitLength.miles)
            ].map { .distance($0) }

        case .photoAsset:
            return unavailable("PHAsset represents an existing Photos-library asset. Static PNG files are available in the Images mode; a synthetic PHAsset would not be genuine.")
        case .nativeCalendarEvent:
            return unavailable("A native Calendar Event is not a public App Intents output type we can synthesize. Choose Calendar .ics to inspect actual event files.")
        case .nativeReminder:
            return unavailable("A native Reminder is not a public App Intents output type we can synthesize without creating a user's reminder. Choose Reminders .ics to inspect VTODO files.")
        case .nativeMusic:
            return unavailable("An Apple Music library track must come from a music catalog. Music WAV examples are valid audio files, not library-track objects.")
        case .installedApp:
            return unavailable("Installed-app items in Shortcuts are system-owned. The app cannot fabricate those native objects. AppEntity shows custom app-owned rows.")
        case .systemShortcut:
            return unavailable("SystemShortcut values represent existing system shortcuts; they cannot be synthesized as dummy examples.")
        case .audioSearch:
            return unavailable("AudioSearch is a Siri media search request, not a standalone song or audio item that can be constructed as a sample track.")
        case .semanticContent:
            return unavailable("SemanticContentDescriptor is contextual data, not a synthetic preview item. No fabricated instance is returned.")
        case .recurrenceRule:
            return unavailable("A recurrence rule is not a Calendar Event. The Calendar .ics mode returns valid event files with real VEVENT components.")
        }
    }

    private static func unavailable(_ explanation: String) -> [ObjectTypeLabValue] {
        // Intentionally *plain text*, clearly identifying that there is no
        // native instance to offer. Never impersonate an unsupported type.
        [.text("NOT AVAILABLE AS A SYNTHETIC NATIVE ITEM: \(explanation)")]
    }

    private static func person(
        _ title: String, email: String, id: String, icon: String
    ) -> ObjectTypeLabValue {
        .person(IntentPerson(
            identifier: .applicationDefined("dav.lab.\(id)"),
            name: .displayName(title),
            handle: .init(emailAddress: email),
            image: DisplayRepresentation.Image(systemName: icon, isTemplate: true)
        ))
    }
}
