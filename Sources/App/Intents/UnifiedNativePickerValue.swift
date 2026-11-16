import AppIntents
import Foundation

/// Preserve the original data type of each selection. In particular, the
/// rich case is the SAME AppEntity used by LAB: Searchable Rich Objects.
@UnionValue
enum UnifiedNativePickerValue {
    case rich(SearchableRichSampleEntity)
    case contact(IntentPerson)
    case menu(MixedMenuChoiceEntity)
}

extension UnifiedNativePickerValue {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Mixed Native Picker Item"
    }

    static let caseDisplayRepresentations: [Cases: DisplayRepresentation] = [
        .rich: "Rich Demo Object",
        .contact: "Contact",
        .menu: "Menu Item"
    ]
}
