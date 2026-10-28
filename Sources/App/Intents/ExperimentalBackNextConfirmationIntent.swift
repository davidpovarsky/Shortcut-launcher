import AppIntents
import Foundation
import SwiftUI

// IMPORTANT: Experimental only. Apple says cancellation of
// requestConfirmation ends the App Intent and recommends not catching it.
// This action deliberately catches the thrown error to discover what
// actually happens in the iPadOS 27 Shortcuts host. It is not production
// navigation code, nor does "back" rewind the Shortcut to a previous action.

enum ConfirmationBranchExperiment {
    static let nextValue = "next"
    static let backValue = "back"
    static let storageKey = "lab.confirmationBranchExperiment.lastTrace.v1"

    struct Trace: Codable, Sendable {
        let runID: String
        let observedAt: Date
        let phase: String
        let returnedValue: String?
        let errorType: String?
        let errorDomain: String?
        let errorCode: Int?

        var description: String {
            var fields = [
                "runID=\(runID)",
                "phase=\(phase)",
                "value=\(returnedValue ?? "none")",
                "recordedAt=\(ISO8601DateFormatter().string(from: observedAt))"
            ]
            if let errorType {
                fields.append("errorType=\(errorType)")
            }
            if let errorDomain {
                fields.append("errorDomain=\(errorDomain)")
            }
            if let errorCode {
                fields.append("errorCode=\(errorCode)")
            }
            return fields.joined(separator: "\n")
        }
    }

    static func store(
        runID: String,
        phase: String,
        value: String? = nil,
        error: Error? = nil
    ) {
        let nsError = error.map { $0 as NSError }
        let trace = Trace(
            runID: runID,
            observedAt: Date(),
            phase: phase,
            returnedValue: value,
            errorType: error.map { String(reflecting: type(of: $0)) },
            errorDomain: nsError?.domain,
            errorCode: nsError?.code
        )
        guard let data = try? JSONEncoder().encode(trace) else { return }
        AppEnvironment.sharedDefaults.set(data, forKey: storageKey)
    }

    static func lastTrace() -> Trace? {
        guard let data = AppEnvironment.sharedDefaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Trace.self, from: data)
    }

    static func lastTraceText() -> String {
        lastTrace()?.description ?? "No confirmation experiment has been recorded yet."
    }
}

/// Deliberately attempts to turn a confirmation cancellation into a regular
/// Shortcuts value. Test whether iPadOS lets "back" reach the next action.
/// Apple documentation explicitly discourages catching this cancellation.
struct ExperimentalBackNextConfirmationIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Confirmation Back or Next"
    static let description = IntentDescription(
        "EXPERIMENT: show custom system labels חזור / המשך and attempt to return back / next into the following Shortcut action, including an intentionally caught cancellation."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let runID = UUID().uuidString
        ConfirmationBranchExperiment.store(runID: runID, phase: "before_prompt")

        do {
            try await requestConfirmation(
                actionName: .custom(
                    acceptLabel: "המשך",
                    acceptAlternatives: [],
                    denyLabel: "חזור",
                    denyAlternatives: [],
                    destructive: false
                ),
                dialog: "בחר אם להמשיך או לחזור (ניסוי בלבד)",
                showDialogAsPrompt: true
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Confirmation Branch Lab", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                    Text("ניסוי כפתורי מערכת: חזור / המשך")
                        .font(.title3.weight(.semibold))
                    Text("המשך אמור להחזיר next. חזור ינסה להחזיר back גם אם המערכת מסמנת ביטול.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            ConfirmationBranchExperiment.store(
                runID: runID,
                phase: "returned_next",
                value: ConfirmationBranchExperiment.nextValue
            )
            return .result(value: ConfirmationBranchExperiment.nextValue)
        } catch {
            // Experimental, contrary to Apple's guidance. iPadOS may end the
            // surrounding Shortcut before this catch is reached, or after it
            // executes. The trace distinguishes those possibilities.
            ConfirmationBranchExperiment.store(
                runID: runID,
                phase: "caught_confirmation_error_returned_back",
                value: ConfirmationBranchExperiment.backValue,
                error: error
            )
            return .result(value: ConfirmationBranchExperiment.backValue)
        }
    }
}

/// Runs separately, including after a failed/canceled Shortcut, so it is
/// possible to determine whether the previous intent's catch block ran.
struct ReadConfirmationBranchTraceIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Read Confirmation Trace"
    static let description = IntentDescription(
        "Read the last recorded state of the experimental Back / Next confirmation."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: ConfirmationBranchExperiment.lastTraceText())
    }
}
