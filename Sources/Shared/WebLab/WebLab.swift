import Foundation
import AppIntents
import Network
import ActivityKit

struct WebLabActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
    }
    var startedAt: Date
}

enum WebLabLog {
    private static let lock = NSLock()

    private static var fileURL: URL {
        let manager = FileManager.default
        let directory = manager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.dav.DavLauncher"
        ) ?? manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("dav-web-lab.log")
    }

    static func write(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL
        let text = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(text.utf8))
    }

    static func read() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return "No server events recorded yet."
        }
        return String(content.suffix(12000))
    }
}

enum WebLabError: LocalizedError {
    case startupTimeout
    case serverStopped
    case invalidHTTPResponse

    var errorDescription: String? {
        switch self {
        case .startupTimeout: "Listener did not reach ready within 6 seconds"
        case .serverStopped: "Listener stopped before becoming ready"
        case .invalidHTTPResponse: "HTTP /health probe was not HTTP 200 with alive=true"
        }
    }
}

/// A deliberately short-lived localhost-only diagnostic server. Separate app and
/// App Intent processes will each have their own singleton; this does not keep
/// the iOS app alive once the system suspends the process.
final class WebLabServer: @unchecked Sendable {
    static let shared = WebLabServer()
    static let baseURL = URL(string: "http://127.0.0.1:8765/")!

    private let queue = DispatchQueue(label: "dav.web.lab.listener")
    private var listener: NWListener?
    private var waiters: [CheckedContinuation<Void, Error>] = []
    private var isReady = false
    private var session: UUID?
    private var startedAt: Date?
    private var expiresAt: Date?
    private var status = "not started"
    private var activeConnections: [UUID: NWConnection] = [:]

    private init() {}

    func snapshot() -> String {
        queue.sync {
            let seconds = expiresAt.map { max(0, Int($0.timeIntervalSinceNow)) } ?? 0
            return "\(status) | ready=\(isReady) | remaining=\(seconds)s"
        }
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if self.isReady {
                    WebLabLog.write("Listener already ready in this process")
                    continuation.resume()
                    return
                }
                self.waiters.append(continuation)
                guard self.listener == nil else { return }

                do {
                    let parameters = NWParameters.tcp
                    // Avoid setting requiredLocalEndpoint AND passing the same
                    // explicit port to NWListener; that combination throws EINVAL.
                    parameters.acceptLocalOnly = true
                    let listener = try NWListener(using: parameters, on: 8765)
                    let session = UUID()
                    self.listener = listener
                    self.session = session
                    self.status = "starting"
                    WebLabLog.write("Creating listener on loopback, TCP port 8765")

                    listener.stateUpdateHandler = { [weak self] newState in
                        guard let self, self.session == session else { return }
                        self.didChangeState(newState, session: session)
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        self?.accept(connection)
                    }
                    listener.start(queue: self.queue)

                    self.queue.asyncAfter(deadline: .now() + 6) { [weak self] in
                        guard let self, self.session == session, !self.isReady else { return }
                        WebLabLog.write("Listener startup timed out")
                        self.close(reason: "startup timeout", error: WebLabError.startupTimeout)
                    }
                } catch {
                    WebLabLog.write("Listener creation ERROR: \(error)")
                    self.close(reason: "creation failed: \(error)", error: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            guard self.listener != nil else {
                WebLabLog.write("Stop requested; no listener owned by this process")
                return
            }
            self.close(reason: "manually stopped", error: WebLabError.serverStopped)
        }
    }

    /// Recover only listeners and sockets owned by this process.
    func resetOwnedListener() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if self.listener != nil {
                    self.close(reason: "local recovery reset", error: WebLabError.serverStopped)
                } else {
                    WebLabLog.write("Local recovery: no owned listener to reset")
                }
                continuation.resume()
            }
        }
    }

    /// A fixed-port recovery attempt: reuse a responsive server; otherwise
    /// reset only our own listener and attempt to bind once. A suspended
    /// separate App Intent process cannot be killed by this process.
    static func ensureHealthy() async throws -> String {
        WebLabLog.write("Recovery: probing existing port 8765")
        if let response = try? await healthCheck(timeout: 1.5) {
            WebLabLog.write("Recovery: reusing responsive listener")
            return response
        }
        WebLabLog.write("Recovery: existing port unresponsive; resetting owned listener")
        await shared.resetOwnedListener()
        do {
            try await shared.start()
        } catch {
            if let response = try? await healthCheck(timeout: 1.5) {
                WebLabLog.write("Recovery: another listener became healthy during bind")
                return response
            }
            WebLabLog.write("Recovery: cannot reclaim port from another process: \(error)")
            throw error
        }
        return try await healthCheck(timeout: 3)
    }

    private func didChangeState(_ state: NWListener.State, session: UUID) {
        WebLabLog.write("Listener state: \(state)")
        switch state {
        case .ready:
            isReady = true
            status = "READY on port \(listener?.port?.rawValue ?? 0)"
            startedAt = Date()
            expiresAt = Date().addingTimeInterval(120)
            let currentWaiters = waiters
            waiters.removeAll()
            currentWaiters.forEach { $0.resume() }
            queue.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self, self.session == session else { return }
                self.close(reason: "120-second timer expired", error: WebLabError.serverStopped)
            }
        case .failed(let error):
            close(reason: "listener failed: \(error)", error: error)
        case .cancelled:
            close(reason: "listener cancelled", error: WebLabError.serverStopped)
        case .waiting(let error):
            status = "waiting: \(error)"
        case .setup:
            status = "setup"
        @unknown default:
            status = "unknown state"
        }
    }

    private func close(reason: String, error: Error) {
        let oldListener = listener
        let connections = activeConnections.values
        activeConnections.removeAll()
        connections.forEach { $0.cancel() }
        listener = nil
        session = nil
        isReady = false
        expiresAt = nil
        status = reason
        let pending = waiters
        waiters.removeAll()
        oldListener?.cancel()
        pending.forEach { $0.resume(throwing: error) }
        WebLabLog.write("Listener stopped: \(reason)")
    }

    private func accept(_ connection: NWConnection) {
        // Even if a platform ignores the interface restriction, never serve
        // HTTP to a non-loopback peer.
        let peer = String(describing: connection.endpoint).lowercased()
        guard peer.contains("127.0.0.1") || peer.contains("::1") else {
            WebLabLog.write("Rejected non-loopback peer: \(peer)")
            connection.cancel()
            return
        }
        let connectionID = UUID()
        activeConnections[connectionID] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                self?.activeConnections.removeValue(forKey: connectionID)
            }
        }
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, error in
            guard self != nil else { connection.cancel(); return }
            if let error {
                WebLabLog.write("HTTP receive ERROR: \(error)")
                connection.cancel()
                return
            }
            let request = String(decoding: data ?? Data(), as: UTF8.self)
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            let contentType: String
            let content: String
            if path.hasPrefix("/health") {
                contentType = "application/json; charset=utf-8"
                let elapsed = max(0, Int(Date().timeIntervalSince(self?.startedAt ?? Date())))
                content = "{\"alive\":true,\"elapsedSeconds\":\(elapsed),\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\"}"
            } else if path.hasPrefix("/log") {
                contentType = "text/plain; charset=utf-8"
                content = WebLabLog.read()
            } else {
                contentType = "text/html; charset=utf-8"
                content = Self.page
            }
            WebLabLog.write("HTTP request \(path) from \(peer)")
            let bytes = Data(content.utf8)
            let headers = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(bytes.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(headers.utf8) + bytes, completion: .contentProcessed { sendError in
                if let sendError { WebLabLog.write("HTTP send ERROR: \(sendError)") }
                connection.cancel()
            })
        }
    }

    /// Checks actual HTTP responses, rather than merely the listener's state.
    static func healthCheck(timeout: TimeInterval = 4) async throws -> String {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8765/health")!)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WebLabError.invalidHTTPResponse
        }
        let text = String(decoding: data, as: UTF8.self)
        guard text.contains("\"alive\":true") else { throw WebLabError.invalidHTTPResponse }
        WebLabLog.write("HTTP self-check OK: \(text)")
        return text
    }

    static let page = #"""
<!doctype html>
<html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta charset="utf-8"><title>Dav Web Lab</title>
<style>
*{box-sizing:border-box}body{font:17px -apple-system,BlinkMacSystemFont,sans-serif;margin:0;background:#101b36;color:#fff;padding:24px}
main{max-width:520px;margin:auto}.tag{color:#74e5d2;text-transform:uppercase;letter-spacing:2px;font-size:12px}
h1{font-size:30px;margin:12px 0}.card{background:#22304d;border-radius:18px;padding:20px;margin:16px 0;box-shadow:0 8px 24px #060c1b55}
button{background:#74e5d2;color:#101b36;border:0;border-radius:12px;padding:14px 16px;font-weight:700;font-size:15px;margin:4px}
pre{white-space:pre-wrap;word-break:break-word;background:#141f37;border-radius:12px;padding:14px;min-height:70px;font-size:13px}
small{color:#a8b4cb}
</style><main><div class="tag">Dav Launcher / Localhost experiment</div><h1>Web server is responding</h1>
<div class="card"><b>Live HTTP connection</b><p><small>Health check repeats every 10 seconds. The experiment has a 120-second deadline.</small></p>
<button onclick="ping()">Check /health</button><button onclick="logs()">Read server log</button>
<pre id="result">Waiting for response...</pre></div>
<div class="card"><b>Interactive HTML control</b><p id="counter">Button clicks: 0</p>
<button onclick="count++;document.getElementById('counter').textContent='Button clicks: '+count">Click me</button></div>
</main><script>
let count=0;
async function ping(){try{
let r=await fetch('/health?nocache='+Date.now(),{cache:'no-store'});
document.getElementById('result').textContent='HTTP '+r.status+'\n'+await r.text()
}catch(e){document.getElementById('result').textContent='Connection FAILED: '+e}}
async function logs(){try{
document.getElementById('result').textContent=await(await fetch('/log?nocache='+Date.now(),{cache:'no-store'})).text()
}catch(e){document.getElementById('result').textContent='Connection FAILED: '+e}}
setInterval(ping,10000);ping();
</script></html>
"""#
}

struct StartWebLabIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB Start Local Web Server"
    static let description = IntentDescription("Starts localhost HTTP for 120 seconds. Returns URL only after listener is ready and /health responds.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            WebLabLog.write("AppIntent invoked; starting loopback server")
            let result = try await WebLabServer.ensureHealthy()
            WebLabLog.write("AppIntent verified real HTTP connection: \(result)")
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                do {
                    _ = try Activity<WebLabActivityAttributes>.request(
                        attributes: WebLabActivityAttributes(startedAt: Date()),
                        content: ActivityContent(state: .init(status: "HTTP 127.0.0.1:8765"), staleDate: Date().addingTimeInterval(120)),
                        pushType: nil
                    )
                    WebLabLog.write("Live Activity request succeeded")
                } catch {
                    WebLabLog.write("Live Activity request failed: \(error)")
                }
            } else {
                WebLabLog.write("Live Activity unavailable or disabled")
            }
            return .result(value: WebLabServer.baseURL.absoluteString)
        } catch {
            WebLabLog.write("AppIntent ERROR: \(error)")
            return .result(value: "ERROR: \(error.localizedDescription)")
        }
    }
}

struct WebLabLogIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB Read Web Server Log"
    static let openAppWhenRun: Bool = false
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: WebLabLog.read())
    }
}
