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

        // Legacy SiriKit catalog action: make it discoverable in Shortcuts.
        // Keep the parameter empty so the user can test runtime resolution.
        let searchIntent = DavSearchCatalogIntent()
        searchIntent.suggestedInvocationPhrase = "Search Dav demo catalog"
        let searchInteraction = INInteraction(intent: searchIntent, response: nil)
        searchInteraction.identifier = "dav.search.sirikit.catalog"
        searchInteraction.donate { error in
            if let error {
                NSLog("Dav SiriKit catalog donation failed: %@", String(describing: error))
            } else {
                NSLog("Dav SiriKit catalog donation succeeded")
            }
        }
    }
}
