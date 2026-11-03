import AppIntents
import Foundation

struct StartDavVPNIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Start Dav VPN"
    static let description = IntentDescription("Requests the experimental VPN tunnel to start. Requires an approved VPN profile and a functioning tunnel backend.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try await VPNLabManager.shared.startVPN()
        return .result(value: VPNLabManager.shared.status)
    }
}

struct StopDavVPNIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Stop Dav VPN"
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await VPNLabManager.shared.stopVPN()
        return .result()
    }
}

struct StartVPNHostedServerIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Start VPN-Hosted Server"
    static let description = IntentDescription("Checks the VPN-hosted server capability. Fails explicitly until a compliant server implementation is verified.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = true

    func perform() async throws -> some IntentResult & ReturnsValue<URL> {
        if true { throw VPNLabError.serverUnsupported }
        return .result(value: URL(string: "http://127.0.0.1:8765")!)
    }
}
