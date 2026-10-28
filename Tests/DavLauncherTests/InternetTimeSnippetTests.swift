import Foundation
import XCTest
@testable import DavLauncher

final class InternetTimeSnippetTests: XCTestCase {
    func testDecodesActualInternetTimeAPIFields() throws {
        let data = Data(
            #"{"utc_iso":"2026-10-28T21:46:46Z","unix_ms":1793224006471,"unix":1793224006,"day_of_year":301}"#.utf8
        )
        let result = try JSONDecoder().decode(InternetTimeAPIResponse.self, from: data)
        XCTAssertEqual(result.utc_iso, "2026-10-28T21:46:46Z")
        XCTAssertEqual(result.unix_ms, 1_793_224_006_471)
    }

    func testServerTimestampFormatting() {
        XCTAssertEqual(
            InternetTimeSnippetFormatting.utcClock(fromISO8601: "2026-10-28T21:46:46Z"),
            "21:46:46"
        )
        XCTAssertEqual(
            InternetTimeSnippetFormatting.israelClock(fromUnixMilliseconds: 1_793_224_006_471),
            "23:46:46"
        )
    }

    func testReadingPersistsOnlyActualServerTime() throws {
        var reading = InternetTimeSnippetReading()
        XCTAssertFalse(reading.hasServerTime)
        XCTAssertEqual(reading.serverUTC, "—")
        reading.serverUTC = "21:46:46"
        reading.serverUnixMilliseconds = 1_793_224_006_471
        reading.successCount = 1

        let decoded = try JSONDecoder().decode(
            InternetTimeSnippetReading.self,
            from: JSONEncoder().encode(reading)
        )
        XCTAssertEqual(decoded.serverUnixMilliseconds, reading.serverUnixMilliseconds)
        XCTAssertEqual(decoded.successCount, 1)
        XCTAssertTrue(decoded.hasServerTime)
    }
}
