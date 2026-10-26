import Intents

final class SiriPanelIntentHandler: INExtension, DavShowPanelIntentHandling {
    override func handler(for intent: INIntent) -> Any {
        self
    }

    func handle(intent: DavShowPanelIntent, completion: @escaping (DavShowPanelIntentResponse) -> Void) {
        completion(DavShowPanelIntentResponse(code: .success, userActivity: nil))
    }
}
