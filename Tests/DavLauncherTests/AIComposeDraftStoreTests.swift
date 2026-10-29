import Foundation
import XCTest
@testable import DavLauncher

final class AIComposeDraftStoreTests: XCTestCase {
    func testSanitizesFilenames() {
        XCTAssertEqual(
            AIComposeDraftStore.safeDisplayName("/private/tmp/report.pdf"),
            "report.pdf"
        )
        XCTAssertEqual(
            AIComposeDraftStore.safeDisplayName("photo:vacation.png"),
            "photovacation.png"
        )
        XCTAssertEqual(
            AIComposeDraftStore.safeDisplayName(""),
            "attachment"
        )
    }

    func testAttachmentAndDraftManifestCodableRoundTrip() throws {
        let attachment = AIComposeAttachment(
            id: "test-file",
            name: "report.pdf",
            relativePath: "file-uuid.pdf",
            typeIdentifier: "com.adobe.pdf",
            sizeInBytes: 3210,
            source: "file-picker"
        )
        let draft = AIComposeDraft(
            id: UUID().uuidString,
            createdAt: Date(timeIntervalSince1970: 1_793_224_006),
            message: "נא לסכם את הקובץ",
            source: "system-share-compose",
            sharedText: ["https://example.org"],
            attachments: [attachment]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(draft)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(AIComposeDraft.self, from: data)

        XCTAssertEqual(parsed.message, draft.message)
        XCTAssertEqual(parsed.source, "system-share-compose")
        XCTAssertEqual(parsed.sharedText, ["https://example.org"])
        XCTAssertEqual(parsed.attachments, [attachment])
        XCTAssertEqual(parsed.createdAt, draft.createdAt)
    }

    func testEnforcesSharedGroupInsteadOfPrivateFallback() {
        // SideStore-re-signed builds use a resolved App Group. A missing
        // container must not silently write into the extension's private
        // standard UserDefaults or private Documents directory.
        XCTAssertEqual(AIComposeDraftStore.directoryName, "AIComposeInbox")
        XCTAssertEqual(AIComposeDraftStore.maximumFiles, 20)
        XCTAssertEqual(AIComposeDraftStore.maximumFileBytes, 80 * 1024 * 1024)
    }
}
