import Foundation
import XCTest
@testable import DavLauncher

final class RuntimeTextListExperimentsTests: XCTestCase {
    func testSizedOutputPreservesOrderDuplicatesAndUnicode() {
        let output = RuntimeTextListExperiment.resultText(
            ["שלום", "עולם", "שלום"],
            variant: "SIZED (1-8) / requestValue()"
        )
        XCTAssertTrue(output.contains("SIZED (1-8) / requestValue()"))
        XCTAssertTrue(output.contains("Items: 3"))
        XCTAssertTrue(output.contains("1. שלום\n2. עולם\n3. שלום"))
    }

    func testEmptyCollectionAndEmptyStringAreDistinguishable() {
        let emptyList = RuntimeTextListExperiment.resultText([], variant: "PLAIN")
        XCTAssertTrue(emptyList.contains("Items: 0"))
        XCTAssertTrue(emptyList.contains("(No items returned)"))

        let oneEmptyString = RuntimeTextListExperiment.resultText([""], variant: "PLAIN")
        XCTAssertTrue(oneEmptyString.contains("Items: 1"))
        XCTAssertTrue(oneEmptyString.contains("1. <empty>"))
    }

    func testMultilineTextValuePreserved() {
        let output = RuntimeTextListExperiment.resultText(
            ["one\ntwo", "three"],
            variant: "PLAIN"
        )
        XCTAssertTrue(output.contains("1. one\ntwo\n2. three"))
    }
}
