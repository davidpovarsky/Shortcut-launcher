import Foundation
import XCTest
@testable import DavLauncher

final class ConfirmationBranchExperimentTests: XCTestCase {
    func testBranchOutputTokensAreStable() {
        XCTAssertEqual(ConfirmationBranchExperiment.nextValue, "next")
        XCTAssertEqual(ConfirmationBranchExperiment.backValue, "back")
        XCTAssertNotEqual(ConfirmationBranchExperiment.nextValue, ConfirmationBranchExperiment.backValue)
    }

    func testTraceRoundTripAndOutput() throws {
        let trace = ConfirmationBranchExperiment.Trace(
            runID: "probe-123",
            observedAt: Date(timeIntervalSince1970: 1_793_224_006),
            phase: "caught_confirmation_error_returned_back",
            returnedValue: "back",
            errorType: "CancellationError",
            errorDomain: "Swift.CancellationError",
            errorCode: 1
        )
        let data = try JSONEncoder().encode(trace)
        let decoded = try JSONDecoder().decode(
            ConfirmationBranchExperiment.Trace.self,
            from: data
        )
        XCTAssertEqual(decoded.runID, "probe-123")
        XCTAssertEqual(decoded.phase, "caught_confirmation_error_returned_back")
        XCTAssertEqual(decoded.returnedValue, "back")
        XCTAssertTrue(decoded.description.contains("errorType=CancellationError"))
        XCTAssertTrue(decoded.description.contains("errorCode=1"))
    }
}
