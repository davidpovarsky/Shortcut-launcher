import SwiftUI

struct VPNLabView: View {
    @StateObject private var vpn = VPNLabManager.shared
    @State private var busy = false

    var body: some View {
        Form {
            Section("VPN profile") {
                LabeledContent("Status", value: vpn.status)
                if let error = vpnError ?? vpn.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                Button("Install / request VPN permission") { execute { try await vpn.installProfile() } }
                Button("Connect VPN") { execute { try await vpn.startVPN() } }
                Button("Disconnect VPN") { Task { await vpn.stopVPN() } }
                Button("Remove VPN profile", role: .destructive) { execute { try await vpn.removeProfile() } }
                Button("Refresh status") { Task { await vpn.refresh() } }
            }
            .disabled(busy)
            Section("Local server") {
                Text("The existing Web Server Lab remains available separately. Apple does not support using a packet tunnel provider as a generic local HTTP server. The VPN connection is not proof of background HTTP availability.")
                    .font(.footnote)
                NavigationLink("Open existing Web Server Lab") { WebLabView() }
            }
            Section("Important") {
                Text("Experimental infrastructure only. The tunnel deliberately refuses to connect until a real, compliant packet-forwarding implementation is supplied. This prevents a misleading connected state or black-holed network traffic.")
                    .font(.footnote)
            }
        }
        .navigationTitle("VPN Lab")
        .task { await vpn.refresh() }
    }

    private func execute(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        Task {
            do { try await action() }
            catch { vpnError = error.localizedDescription }
            busy = false
        }
    }

    @State private var vpnError: String?
}
