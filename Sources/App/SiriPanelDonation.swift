import Intents
import Foundation

enum SiriPanelDonation {
    static func donate() {
        let intent = DavShowPanelIntent()
        intent.suggestedInvocationPhrase = "Show Dav Siri Panel"
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = "dav.show.siri.panel"
        interaction.donate { error in
            if let error {
                NSLog("Dav Siri Panel donation failed: %@", String(describing: error))
            } else {
                NSLog("Dav Siri Panel donation succeeded")
            }
        }
    }
}
