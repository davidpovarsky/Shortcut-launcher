# VPN Lab (experimental, fail-closed)

The VPN extension is a genuine Network Extension target, with a system profile
manager, Settings screen and Shortcuts actions. **It does not yet provide a
working VPN or a persistent localhost server.** Its provider intentionally
returns an error instead of falsely reporting success or dropping network packets.

## Platform constraints

Apple TN3120 specifically rules out using a packet tunnel provider as a
general-purpose local HTTP/proxy server. A packet tunnel requires a legitimate
packet transport backend. The existing NWListener server belongs to its host
process; creating a VPN profile does not migrate that listener into the provider.

- A paid Apple Developer team with Network Extensions entitlement and matching
  provisioning profiles may be required for device installation.
- The iOS user must explicitly approve VPN configuration in the system prompt.
- Ad-hoc/SideStore re-signing can strip or invalidate restricted entitlements.
- This configuration may conflict with an existing Tailscale VPN.
- Do not turn on a VPN without an actual packet-forwarding backend.

## Shortcuts

- LAB: Start Dav VPN: requests start, but currently the extension rejects it.
- LAB: Stop Dav VPN: stops the configured tunnel.
- LAB: Start VPN-Hosted Server: explicitly fails (no fake localhost URL).

The existing WebLab and its 120-second timer are unchanged.

## Libraries considered

NetworkExtension is Apple's first-party framework for profile management and
packet tunnel lifecycle. WireGuardKit and sing-box provide genuine VPN/tunnel
building blocks but neither grants permission to run a generic HTTP server
inside the extension. Adding either dependency before choosing a real VPN
protocol and remote endpoint would introduce complexity without solving the
user's requested background server behavior.

References:
- https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers
- https://developer.apple.com/documentation/networkextension/netunnelprovidermanager
- https://github.com/WireGuard/wireguard-apple
- https://github.com/SagerNet/sing-box-for-apple
