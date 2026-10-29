import Intents

final class SiriPanelIntentHandler: INExtension, DavShowPanelIntentHandling {
    override func handler(for intent: INIntent) -> Any {
        if intent is DavSearchCatalogIntent {
            return SiriCatalogSearchHandler()
        }
        return self
    }

    func handle(intent: DavShowPanelIntent, completion: @escaping (DavShowPanelIntentResponse) -> Void) {
        completion(DavShowPanelIntentResponse(code: .success, userActivity: nil))
    }
}
