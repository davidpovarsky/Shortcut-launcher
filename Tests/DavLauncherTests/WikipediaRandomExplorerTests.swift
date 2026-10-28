import Foundation
import XCTest
@testable import DavLauncher

final class WikipediaRandomExplorerTests: XCTestCase {
    private let sample = #"""
    {
      "batchcomplete": true,
      "query": {"pages": [{
        "pageid": 21999,
        "ns": 0,
        "title": "ירושלים",
        "extract": "ירושלים היא בירת ישראל והעיר הגדולה במדינה מבחינת מספר התושבים. העיר נמצאת בהרי יהודה ומשמשת מרכז דתי, תרבותי, היסטורי ומנהלי חשוב מזה אלפי שנים.",
        "thumbnail": {
          "source": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Pic.jpg/320px-Pic.jpg",
          "width": 320,
          "height": 210
        },
        "fullurl": "https://he.wikipedia.org/wiki/%D7%99%D7%A8%D7%95%D7%A9%D7%9C%D7%99%D7%9D"
      }]}
    }
    """#

    func testDecodeRandomPageIntoLinkAndSummary() throws {
        let article = try WikipediaRandomArticleAPI.decode(Data(sample.utf8))
        XCTAssertEqual(article.pageID, 21999)
        XCTAssertEqual(article.title, "ירושלים")
        XCTAssertTrue(article.excerpt.hasPrefix("ירושלים היא בירת ישראל"))
        XCTAssertEqual(article.url.host, "he.wikipedia.org")
        XCTAssertNil(article.thumbnailData)
    }

    func testRejectTooShortAndMissingPages() {
        let short = #"""
        {"query":{"pages":[{"pageid":1,"title":"Test","extract":"Short","fullurl":"https://he.wikipedia.org/wiki/Test"}]}}
        """#
        XCTAssertThrowsError(
            try WikipediaRandomArticleAPI.decode(Data(short.utf8))
        )
        XCTAssertThrowsError(
            try WikipediaRandomArticleAPI.decode(Data(#"{"query":{"pages":[]}}"#.utf8))
        )
    }

    func testRejectNonWikipediaURL() {
        let injected = sample.replacingOccurrences(
            of: "https://he.wikipedia.org/wiki/",
            with: "https://example.com/"
        )
        XCTAssertThrowsError(
            try WikipediaRandomArticleAPI.decode(Data(injected.utf8))
        )
    }

    func testRequestIsRandomMainspaceAndUncached() throws {
        let a = WikipediaRandomArticleAPI.makeRequest()
        let b = WikipediaRandomArticleAPI.makeRequest()
        XCTAssertEqual(a.url?.host, "he.wikipedia.org")
        XCTAssertEqual(a.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNotEqual(a.url, b.url)

        let params = try XCTUnwrap(
            URLComponents(url: XCTUnwrap(a.url), resolvingAgainstBaseURL: false)?
                .queryItems
        )
        let values = Dictionary(uniqueKeysWithValues: params.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["generator"], "random")
        XCTAssertEqual(values["grnnamespace"], "0")
        XCTAssertEqual(values["exintro"], "1")
        XCTAssertEqual(values["formatversion"], "2")
        XCTAssertNotNil(values["probe"])
    }

    func testArticleSnapshotCanRoundTripThroughAppGroupStorage() throws {
        let article = try WikipediaRandomArticleAPI.decode(Data(sample.utf8))
        let payload = WikipediaArticleSnapshot(article: article, number: 7)
        let decoded = try JSONDecoder().decode(
            WikipediaArticleSnapshot.self,
            from: JSONEncoder().encode(payload)
        )
        XCTAssertEqual(decoded.article.title, "ירושלים")
        XCTAssertEqual(decoded.article.url, article.url)
        XCTAssertEqual(decoded.number, 7)
    }
}
