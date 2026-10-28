import AppIntents
import Foundation
import SwiftUI

/// An actual *network-fed* snippet experiment:
/// every displayed timestamp comes from https://utctime.app/api/now.
/// This never advances the displayed clock using the iPad's local time.
///
/// A process-owned polling task fetches from the internet approximately once
/// per second, then calls SnippetIntent.reload(). iPadOS controls whether the
/// system-hosted snippet actually accepts that refresh cadence.
struct InternetTimeSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "LAB: Internet Clock (Live)"
    static let description = IntentDescription(
        "Fetch UTC from an external HTTPS time API, attempt one new network request per second, and inspect live Snippet reloads."
    )
    static let isDiscoverable = true
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let monitor = InternetTimeSnippetMonitor.shared
        await monitor.ensureStarted()
        return .result(view: InternetTimeSnippetView(reading: monitor.reading))
    }
}

/// An AppIntent-backed manual refresh is the positive control: if automatic
/// updates are suppressed by iPadOS, this still fetches the actual server.
struct InternetTimeRefreshNowIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Fetch Internet Time Now"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await InternetTimeSnippetMonitor.shared.fetchNow()
        InternetTimeSnippetIntent.reload()
        return .result()
    }
}

struct InternetTimeRestartPollingIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Restart Internet Clock Polling"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await InternetTimeSnippetMonitor.shared.restart()
        InternetTimeSnippetIntent.reload()
        return .result()
    }
}

struct InternetTimeStopPollingIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB: Stop Internet Clock Polling"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        InternetTimeSnippetMonitor.shared.stop()
        InternetTimeSnippetIntent.reload()
        return .result()
    }
}

// MARK: - True external data and visible diagnostics

struct InternetTimeAPIResponse: Decodable, Sendable {
    let utc_iso: String
    let unix_ms: Int64
}

struct InternetTimeNetworkResult: Sendable {
    let response: InternetTimeAPIResponse
    let latencyMilliseconds: Int
}

enum InternetTimeNetworkClient {
    static let sourceURL = "https://utctime.app/api/now"

    static func fetch() async throws -> InternetTimeNetworkResult {
        // Every request has a unique URL to defeat intermediate 1-second
        // caches; the server timestamps in the response are the only clock
        // values that we present as "live internet time".
        var components = URLComponents(string: sourceURL)!
        components.queryItems = [
            URLQueryItem(name: "snippet_probe", value: UUID().uuidString)
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let start = ProcessInfo.processInfo.systemUptime
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = ProcessInfo.processInfo.systemUptime - start

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw InternetTimeNetworkError.httpStatus(code)
        }

        let parsed = try JSONDecoder().decode(InternetTimeAPIResponse.self, from: data)
        guard parsed.unix_ms > 0,
              parsed.utc_iso.count >= 19 else {
            throw InternetTimeNetworkError.invalidPayload
        }

        return InternetTimeNetworkResult(
            response: parsed,
            latencyMilliseconds: Int((elapsed * 1000).rounded())
        )
    }
}

enum InternetTimeNetworkError: LocalizedError {
    case httpStatus(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "HTTP \(code)"
        case .invalidPayload:
            return "Invalid server timestamp"
        }
    }
}

struct InternetTimeSnippetReading: Codable, Sendable {
    var serverUTC: String = "—"
    var serverIsrael: String = "—"
    var serverUnixMilliseconds: Int64 = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var attemptedRequests: Int = 0
    var responseLatencyMilliseconds: Int = 0
    var lastSuccessfulFetch: Date?
    var lastError: String?
    var status: String = "Not started"
    var isPolling: Bool = false

    var hasServerTime: Bool { serverUnixMilliseconds > 0 }
}

enum InternetTimeSnippetFormatting {
    static func utcClock(fromISO8601 text: String) -> String {
        String(text.dropFirst(11).prefix(8))
    }

    static func israelClock(fromUnixMilliseconds timestamp: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(
            from: Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        )
    }
}

// MARK: - Actor-isolated lifecycle

@MainActor
final class InternetTimeSnippetMonitor {
    static let shared = InternetTimeSnippetMonitor()

    private static let storageKey = "internetTimeSnippet.lastNetworkReading.v1"
    private static let experimentDuration: TimeInterval = 120

    private var initialized = false
    private var pollTask: Task<Void, Never>?
    private var deadline: Date?
    private(set) var reading: InternetTimeSnippetReading = InternetTimeSnippetMonitor.restore()

    private init() {}

    func ensureStarted() async {
        guard !initialized else { return }
        initialized = true
        await startNewExperiment()
    }

    func restart() async {
        pollTask?.cancel()
        pollTask = nil
        initialized = true
        reading = InternetTimeSnippetReading()
        await startNewExperiment()
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        reading.isPolling = false
        reading.status = "Stopped manually"
        persist()
    }

    func fetchNow() async {
        await requestServerAndPublish(askToReload: false)
    }

    private func startNewExperiment() async {
        reading.isPolling = true
        reading.status = "Connecting to internet…"
        deadline = Date().addingTimeInterval(Self.experimentDuration)
        persist()

        // Guarantee the *first* displayed time is a real HTTPS response,
        // even if the system refuses to run timers inside a Snippet view.
        await requestServerAndPublish(askToReload: false)
        startPollingLoop()
    }

    private func startPollingLoop() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard self.reading.isPolling else { return }

                if let deadline = self.deadline, Date() >= deadline {
                    self.reading.isPolling = false
                    self.reading.status = "120-second experiment finished"
                    self.persist()
                    InternetTimeSnippetIntent.reload()
                    return
                }

                // One new HTTP request approximately every second.
                // The displayed digits advance ONLY after a server response.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, self.reading.isPolling else { return }
                await self.requestServerAndPublish(askToReload: true)
            }
        }
    }

    private func requestServerAndPublish(askToReload: Bool) async {
        reading.attemptedRequests += 1
        do {
            let result = try await InternetTimeNetworkClient.fetch()
            guard !Task.isCancelled else { return }

            reading.serverUTC = InternetTimeSnippetFormatting.utcClock(
                fromISO8601: result.response.utc_iso
            )
            reading.serverIsrael = InternetTimeSnippetFormatting.israelClock(
                fromUnixMilliseconds: result.response.unix_ms
            )
            reading.serverUnixMilliseconds = result.response.unix_ms
            reading.responseLatencyMilliseconds = result.latencyMilliseconds
            reading.lastSuccessfulFetch = Date()
            reading.lastError = nil
            reading.successCount += 1
            reading.status = reading.isPolling
                ? "Connected — polling internet"
                : "Manual network refresh"
        } catch {
            guard !Task.isCancelled else { return }
            reading.failureCount += 1
            reading.lastError = error.localizedDescription
            reading.status = "Network request failed"
            // Keep the last successful server timestamp unchanged:
            // do NOT simulate the missing second using the device clock.
        }

        persist()
        if askToReload {
            InternetTimeSnippetIntent.reload()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(reading) {
            AppEnvironment.sharedDefaults.set(data, forKey: Self.storageKey)
        }
    }

    private static func restore() -> InternetTimeSnippetReading {
        guard let data = AppEnvironment.sharedDefaults.data(forKey: storageKey),
              var previous = try? JSONDecoder().decode(
                InternetTimeSnippetReading.self,
                from: data
              ) else {
            return InternetTimeSnippetReading()
        }
        // A process restored from storage is not automatically polling.
        previous.isPolling = false
        previous.status = "Saved reading — waiting for connection"
        return previous
    }
}

// MARK: - Snippet-safe SwiftUI presentation

private struct InternetTimeSnippetView: View {
    let reading: InternetTimeSnippetReading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .foregroundStyle(.blue)
                Text("INTERNET CLOCK")
                    .font(.headline)
                Spacer(minLength: 4)
                Circle()
                    .fill(reading.isPolling ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }

            Text("UTC · response from server")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(reading.serverUTC)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .contentTransition(.numericText())

            HStack {
                Text("Israel")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(reading.serverIsrael)
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HTTPS successes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(reading.successCount)")
                        .font(.headline.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network attempts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(reading.attemptedRequests)")
                        .font(.headline.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latency")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(reading.hasServerTime
                         ? "\(reading.responseLatencyMilliseconds) ms" : "—")
                        .font(.headline.monospacedDigit())
                }
            }

            Text(reading.status)
                .font(.caption)
                .foregroundStyle(reading.lastError == nil ? Color.secondary : Color.red)
                .lineLimit(2)

            if let error = reading.lastError {
                Text("Latest error: \(error)")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button(intent: InternetTimeRefreshNowIntent()) {
                    Label("Fetch now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Button(intent: InternetTimeRestartPollingIntent()) {
                    Label("Restart", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
            }

            if reading.isPolling {
                Button(intent: InternetTimeStopPollingIntent()) {
                    Label("Stop automatic requests", systemImage: "stop.circle")
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            Text("Source: utctime.app/api/now • max. 120 seconds per run")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}
