import XCTest
import AppIntents
@testable import DavLauncher

final class UnifiedNativeItemBuilderTests: XCTestCase {
    func testBuildsRealNativeUnionValuesAndPreservesOrdering() async throws {
        let json = """
        [
          {"format":"richObject","id":"report","name":"דוח פעילות","subtitle":"PDF","source":"Files"},
          {"format":"contact","id":"person","name":"Sara Demo","email":"sara@example.com"},
          {"format":"menu","id":"action","title":"Run Action","subtitle":"Menu"}
        ]
        """
        let batch = try await UnifiedNativeItemBuilder.prepare(json)
        defer {
            SearchableRichRuntimeStore.remove(session: batch.session)
            MixedMenuChoiceStore.remove(session: batch.session)
        }
        XCTAssertEqual(batch.values.count, 3)
        XCTAssertEqual(batch.entries.map(\.format.rawValue), ["richObject", "contact", "menu"])

        guard case let .rich(rich) = batch.values[0] else {
            return XCTFail("Rich JSON must produce original SearchableRichSampleEntity")
        }
        XCTAssertEqual(rich.name, "דוח פעילות")
        XCTAssertEqual(rich.source, "Files")
        XCTAssertEqual(SearchableRichRuntimeStore.resolve([rich.id]).first?.name, rich.name)
        XCTAssertEqual(batch.index(of: batch.values[0]), 0)

        guard case let .contact(contact) = batch.values[1] else {
            return XCTFail("Contact JSON must produce native IntentPerson")
        }
        guard case let .applicationDefined(contactID) = contact.identifier else {
            return XCTFail("Contact identifier must be application-defined")
        }
        XCTAssertEqual(contactID, "\(batch.session):1")
        XCTAssertEqual(batch.index(of: batch.values[1]), 1)

        guard case let .menu(menu) = batch.values[2] else {
            return XCTFail("Menu JSON must produce original MixedMenuChoiceEntity")
        }
        XCTAssertEqual(menu.title, "Run Action")
        XCTAssertEqual(MixedMenuChoiceStore.resolve([menu.id]).first?.title, menu.title)
        XCTAssertEqual(batch.index(of: batch.values[2]), 2)

        // A chooser must reject a mismatched type even when its session ID
        // happens to match the ID of a row of another type.
        let forged = MixedMenuChoiceEntity(
            id: rich.id,
            title: "Wrong kind",
            subtitle: "",
            type: "rich",
            imageData: nil
        )
        XCTAssertNil(batch.index(of: .menu(forged)))
    }

    func testBuildRejectsEmptyAndInvalidJSONWithoutPrompting() async throws {
        do {
            _ = try await UnifiedNativeItemBuilder.prepare("[]")
            XCTFail("Empty input should fail")
        } catch {
            XCTAssertNotNil(error as? UnifiedPickerError)
        }

        do {
            _ = try await UnifiedNativeItemBuilder.prepare(
                #"[{"format":"richObject","name":"Bad","color":"invalid"}]"#
            )
            XCTFail("Invalid color should fail")
        } catch {
            XCTAssertNotNil(error as? UnifiedPickerError)
        }
    }
}
