import Foundation
import XCTest
@testable import DavLauncher

final class MixedMenuParserTests: XCTestCase {
    func testArrayCombinesRichAndCardRowsInOriginalOrder() throws {
        let json = """
        [
          {"id":"settings","type":"rich","title":"הגדרות","subtitle":"שינוי העדפות","icon":"gearshape.fill","color":"#64748B","payload":{"mode":"advanced","count":3}},
          {"id":"files","type":"vcard","title":"קבצים","subtitle":"ניהול קבצים","icon":"folder.fill","color":"#F59E0B"}
        ]
        """
        let rows = try MixedMenuParser.parse(json)
        XCTAssertEqual(rows.map(\.id), ["settings", "files"])
        XCTAssertEqual(rows.map(\.type), ["rich", "vcard"])
        XCTAssertEqual(rows.map(\.title), ["הגדרות", "קבצים"])
        XCTAssertEqual(rows[0].subtitle, "שינוי העדפות")
        let original = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(rows[0].rawJSON.utf8)) as? [String: Any]
        )
        let nested = try XCTUnwrap(original["payload"] as? [String: Any])
        XCTAssertEqual(nested["mode"] as? String, "advanced")
        XCTAssertEqual(nested["count"] as? Int, 3)
    }

    func testDictionaryFormKeepsTheKeyOrderAndSuppliesIDs() throws {
        let json = """
        {
          "settings": {"title":"הגדרות","icon":"gearshape.fill","color":"#64748B"},
          "files": {"type":"vcard","title":"קבצים","icon":"folder.fill","color":"#F59E0B"},
          "search": {"title":"חיפוש","icon":"magnifyingglass","color":"#8B5CF6"}
        }
        """
        let rows = try MixedMenuParser.parse(json)
        XCTAssertEqual(rows.map(\.id), ["settings", "files", "search"])
        XCTAssertEqual(rows.map(\.type), ["rich", "vcard", "rich"])
        XCTAssertTrue(rows[0].rawJSON.contains("\"id\":\"settings\""))
    }

    func testNestedObjectKeysAndQuotesDoNotConfuseTopLevelOrdering() throws {
        let json = """
        {
          "first": {"title":"One","payload":{"fake":"two","quote":"{ x }"}},
          "second": {"title":"Two"}
        }
        """
        let rows = try MixedMenuParser.parse(json)
        XCTAssertEqual(rows.map(\.id), ["first", "second"])
    }

    func testRejectsInvalidHexColors() {
        XCTAssertThrowsError(try MixedMenuParser.parse("""
        [{"title":"Bad","color":"64748B#"}]
        """))
        XCTAssertTrue(MixedMenuParser.validHexColor("#64748B"))
        XCTAssertTrue(MixedMenuParser.validHexColor("#11223344"))
        XCTAssertFalse(MixedMenuParser.validHexColor("64748B"))
    }

    func testRejectsDuplicateIDs() {
        XCTAssertThrowsError(try MixedMenuParser.parse("""
        [{"id":"same","title":"One"},{"id":"same","title":"Two"}]
        """))
    }

    func testRejectsUnsupportedTypeAndEmptyMenu() {
        XCTAssertThrowsError(try MixedMenuParser.parse("[]"))
        XCTAssertThrowsError(try MixedMenuParser.parse("""
        [{"type":"unknown","title":"One"}]
        """))
        XCTAssertThrowsError(try MixedMenuParser.parse("not json"))
    }

    func testRejectsOversizedInputAndOversizedPhoto() {
        XCTAssertThrowsError(try MixedMenuParser.parse(String(repeating: "A", count: 1_000_001)))
        let photo = Data(repeating: 0xFF, count: 250_001).base64EncodedString()
        let input = "[{\"title\":\"Picture\",\"imageBase64\":\"\(photo)\"}]"
        XCTAssertThrowsError(try MixedMenuParser.parse(input))
    }

    func testResultCarriesUnrecognizedUserFields() throws {
        let rows = try MixedMenuParser.parse("""
        [{"id":"custom","title":"Custom","data":[1,2,3],"url":"https://example.com","enabled":true}]
        """)
        let data = try XCTUnwrap(rows.first?.rawJSON.data(using: .utf8))
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["id"] as? String, "custom")
        XCTAssertEqual(result["type"] as? String, "rich")
        XCTAssertEqual(result["url"] as? String, "https://example.com")
        XCTAssertEqual(result["enabled"] as? Bool, true)
        XCTAssertEqual(result["data"] as? [Int], [1, 2, 3])
    }
}
