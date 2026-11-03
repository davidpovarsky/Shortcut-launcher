import NetworkExtension

/// Intentional fail-closed scaffold. A packet tunnel must implement genuine
/// packet transport; claiming a connected VPN without forwarding packets can
/// silently disrupt the device's network connectivity.
final class VPNLabPacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(NSError(
            domain: "DavLauncher.VPNLab",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey:
                "No VPN packet-forwarding backend configured. A packet tunnel cannot be used as an unsupported background HTTP server."]
        ))
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
