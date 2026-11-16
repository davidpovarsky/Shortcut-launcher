import XCTest
@testable import DavLauncher

final class UnifiedPickerParserTests: XCTestCase {
    func testMixedArrayPreservesFormatOrderAndFields() throws {
        let json = """
        [
          {"format":"richObject","id":"r1","name":"Annual Report","subtitle":"PDF","source":"Files","tags":["report","design"]},
          {"format":"contact","id":"c1","name":"Sarah Demo","email":"sarah@example.com","phone":"+15551234567"},
          {"format":"menu","id":"m1","type":"vcard","title":"Contact-shaped card","subtitle":"Custom card","color":"#DDAA22"}
        ]
        """
        let entries = try UnifiedPickerParser.parse(json)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.format.rawValue), ["richObject", "contact", "menu"])
        XCTAssertEqual(entries.map(\.appearance.title), ["Annual Report", "Sarah Demo", "Contact-shaped card"])
        XCTAssertEqual(entries[1].appearance.subtitle, "sarah@example.com")
        XCTAssertEqual(entries[2].appearance.type, "vcard")
        let decoded = try entries.map { entry in
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(entry.outputJSON.utf8)) as? [String: Any])
        }
        XCTAssertEqual(decoded[0]["format"] as? String, "richObject")
        XCTAssertEqual((decoded[0]["item"] as? [String: Any])?["source"] as? String, "Files")
        XCTAssertEqual((decoded[1]["item"] as? [String: Any])?["phone"] as? String, "+15551234567")
        XCTAssertEqual((decoded[2]["item"] as? [String: Any])?["type"] as? String, "vcard")
    }

    func testGroupedInputAndFormatDefaults() throws {
        let json = """
        {
          "richObjects": [{"name":"Book","category":"Reading"}],
          "contacts": [{"displayName":"Miriam","emailAddress":"miriam@example.com"}],
          "menuItems": [{"title":"Do it","icon":"bolt.fill"}]
        }
        """
        let entries = try UnifiedPickerParser.parse(json)
        XCTAssertEqual(entries.map(\.format.rawValue), ["richObject", "contact", "menu"])
        XCTAssertEqual(entries.map(\.appearance.icon), ["doc.richtext", "person.crop.circle.fill", "bolt.fill"])
    }

    func testAutoDetectsContactAndMenuEntries() throws {
        let json = """
        {"items":[{"name":"Demo person","email":"example@example.com"},
                  {"title":"Menu card","type":"rich","color":"#001122"}]}
        """
        XCTAssertEqual(try UnifiedPickerParser.parse(json).map(\.format.rawValue), ["contact", "menu"])
    }

    func testLegacyNamedMenuObject() throws {
        let json = """
        {"first":{"title":"First","type":"rich"},"second":{"title":"Second","type":"vcard"}}
        """
        let entries = try UnifiedPickerParser.parse(json)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map(\.appearance.id), ["first", "second"])
    }

    func testRejectsInvalidColorAndEmptyInput() throws {
        XCTAssertThrowsError(try UnifiedPickerParser.parse("[]"))
        XCTAssertThrowsError(try UnifiedPickerParser.parse("""
            [{"format":"contact","name":"Demo","color":"#invalid"}]
            """))
        XCTAssertThrowsError(try UnifiedPickerParser.parse("""
            [{"format":"menu","title":"Wrong","type":"unknown"}]
            """))
    }

    func testRejectsOversizedAndExcessItems() throws {
        let many = Array(repeating: ["format":"menu","title":"Item"], count: 81)
        let data = try JSONSerialization.data(withJSONObject: many)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertThrowsError(try UnifiedPickerParser.parse(text))
        XCTAssertThrowsError(try UnifiedPickerParser.parse(String(repeating:"a", count: 1_000_001)))
    }
}
