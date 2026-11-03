import Combine
import Foundation
import NetworkExtension

/// Manages an experimental packet tunnel configuration. A VPN is NOT a general-purpose
/// background execution entitlement and cannot be used as a supported HTTP server host.
@MainActor
final class VPNLabManager: ObservableObject {
    static let shared = VPNLabManager()
    @Published private(set) var status = "Not configured"
    @Published private(set) var errorMessage: String?
    private let providerID = "com.dav.DavLauncher.VPNLab"
    private var manager: NETunnelProviderManager?

    private init() {}

    func refresh() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID }
            status = manager.map { String(describing: $0.connection.status) } ?? "Not configured"
            errorMessage = nil
        } catch {
            status = "Unavailable"
            errorMessage = error.localizedDescription
        }
    }

    func installProfile() async throws {
        let tunnel = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerID
        proto.serverAddress = "DavLauncher VPN Lab (experimental)"
        tunnel.protocolConfiguration = proto
        tunnel.localizedDescription = "DavLauncher VPN Lab"
        tunnel.isEnabled = true
        try await tunnel.saveToPreferences()
        try await tunnel.loadFromPreferences()
        manager = tunnel
        await refresh()
    }

    func removeProfile() async throws {
        if manager == nil { await refresh() }
        guard let manager else { return }
        manager.connection.stopVPNTunnel()
        try await manager.removeFromPreferences()
        self.manager = nil
        await refresh()
    }

    func startVPN() async throws {
        if manager == nil { await refresh() }
        guard let manager else { throw VPNLabError.profileMissing }
        try await manager.loadFromPreferences()
        guard manager.isEnabled else { throw VPNLabError.profileDisabled }
        try manager.connection.startVPNTunnel()
        await refresh()
    }

    func stopVPN() async {
        if manager == nil { await refresh() }
        manager?.connection.stopVPNTunnel()
        await refresh()
    }
}

enum VPNLabError: LocalizedError {
    case profileMissing, profileDisabled, serverUnsupported
    var errorDescription: String? {
        switch self {
        case .profileMissing: "Install and approve the VPN profile in DavLauncher Settings first."
        case .profileDisabled: "Enable the VPN profile in iOS Settings."
        case .serverUnsupported: "The VPN extension is not an approved or verified localhost HTTP server. No URL is available."
        }
    }
}
