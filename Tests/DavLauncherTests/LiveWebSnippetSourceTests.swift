import XCTest
@testable import DavLauncher

final class LiveWebSnippetSourceTests: XCTestCase {
    func testAcceptsHTTPSAndLocalHTTP() {
        XCTAssertEqual(
            LiveWebSnippetSource.webURL(from: "  https://example.org/test?q=1  ")?.absoluteString,
            "https://example.org/test?q=1"
        )
        XCTAssertEqual(
            LiveWebSnippetSource.webURL(from: "http://127.0.0.1:8765/")?.host,
            "127.0.0.1"
        )
    }

    func testDoesNotTreatMarkupOrCustomSchemesAsWebsites() {
        XCTAssertNil(LiveWebSnippetSource.webURL(from: "<html>Hello</html>"))
        XCTAssertNil(LiveWebSnippetSource.webURL(from: "javascript:alert(1)"))
        XCTAssertNil(LiveWebSnippetSource.webURL(from: "file:///private/test.html"))
        XCTAssertNil(LiveWebSnippetSource.webURL(from: "example.org"))
    }

    func testEmptySourceShowsInteractiveDemo() {
        let html = LiveWebSnippetSource.html(from: "   ")
        XCTAssertTrue(html.contains("navigator.share"))
        XCTAssertTrue(html.contains("type=\"file\""))
        XCTAssertTrue(html.contains("לחיצה חיה"))
    }

    func testSuppliedHTMLIsNotAltered() {
        let html = "<!DOCTYPE html><html><body>Hi</body></html>"
        XCTAssertEqual(LiveWebSnippetSource.html(from: html), html)
    }
}
