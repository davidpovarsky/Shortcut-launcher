import SwiftUI

/// A positive control for the Web Lab: this screen starts the listener inside
/// the foreground app process, independent of Shortcuts/App Intents.
struct WebLabView: View {
    @State private var listenerStatus = "Not checked"
    @State private var healthResponse = "Not tested"
    @State private var recentLog = ""
    @State private var isStarting = false

    var body: some View {
        Form {
            Section("120-second local HTTP experiment") {
                LabeledContent("Address", value: "http://127.0.0.1:8765/")
                Text("The server only accepts localhost clients. Open this page in the app and start the listener to test foreground execution first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    isStarting = true
                    Task {
                        do {
                            try await WebLabServer.shared.start()
                            healthResponse = "HTTP OK: " + (try await WebLabServer.healthCheck())
                        } catch {
                            healthResponse = "ERROR: \(error)"
                        }
                        isStarting = false
                        refresh()
                    }
                } label: {
                    Label("Start server and verify HTTP", systemImage: "play.fill")
                }
                .disabled(isStarting)

                Button {
                    Task { await checkHTTP() }
                } label: {
                    Label("Check /health right now", systemImage: "checkmark.shield")
                }

                Link(destination: WebLabServer.baseURL) {
                    Label("Open interactive HTML page", systemImage: "safari")
                }

                Button(role: .destructive) {
                    WebLabServer.shared.stop()
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        refresh()
                    }
                } label: {
                    Label("Stop server", systemImage: "stop.fill")
                }
            }
            Section("Live status") {
                Text(listenerStatus).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Text(healthResponse).font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            Section {
                Button("Refresh status and diagnostics") { refresh() }
                Text(recentLog)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Text("Persistent server log")
            } footer: {
                Text("The App Intent can run in a different system process. If HTTP works here but fails after the Shortcuts action returns, process suspension is the likely cause. A Live Activity does not guarantee a persistent process.")
            }
        }
        .navigationTitle("Web Server Lab")
        .task { refresh() }
    }

    @MainActor
    private func checkHTTP() async {
        do {
            healthResponse = "HTTP OK: " + (try await WebLabServer.healthCheck())
        } catch {
            healthResponse = "HTTP ERROR: \(error)"
        }
        refresh()
    }

    private func refresh() {
        listenerStatus = WebLabServer.shared.snapshot()
        recentLog = WebLabLog.read()
    }
}
