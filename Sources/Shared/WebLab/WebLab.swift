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
    static func write(_ message: String) {
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.dav.DavLauncher")?.appendingPathComponent("web-lab.log")
        guard let url else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
    static func read() -> String {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.dav.DavLauncher")?.appendingPathComponent("web-lab.log") else { return "No log" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "No log yet"
    }
}

final class WebLabServer: @unchecked Sendable {
    static let shared = WebLabServer()
    private let queue = DispatchQueue(label: "dav.web.lab")
    private var listener: NWListener?
    private var started: Date?
    private init() {}

    func start() throws {
        if listener != nil { return }
        let tcp = NWParameters.tcp
        tcp.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: 8765)
        let listener = try NWListener(using: tcp, on: 8765)
        self.listener = listener
        self.started = Date()
        listener.stateUpdateHandler = { state in WebLabLog.write("listener: \(state)") }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        WebLabLog.write("server start requested port=8765")
        queue.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
            WebLabLog.write("server 120-second timeout")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
            let request = String(data: data ?? Data(), encoding: .utf8) ?? ""
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            let body: String
            let type: String
            if path.hasPrefix("/health") {
                type = "application/json"
                let elapsed = Int(Date().timeIntervalSince(self?.started ?? Date()))
                body = "{\"alive\":true,\"elapsedSeconds\":\(elapsed),\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date()))\"}"
            } else if path.hasPrefix("/log") {
                type = "text/plain; charset=utf-8"
                body = WebLabLog.read()
            } else {
                type = "text/html; charset=utf-8"
                body = Self.page
            }
            WebLabLog.write("HTTP \(path)")
            let bytes = Data(body.utf8)
            let header = "HTTP/1.1 200 OK\r\nContent-Type: \(type)\r\nContent-Length: \(bytes.count)\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(header.utf8) + bytes, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
    static let page = #"""
<!doctype html><html lang="he" dir="rtl"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dav Web Lab</title><style>body{font:17px system-ui;background:#101a32;color:white;padding:22px}button{background:#69d6c7;border:0;border-radius:12px;padding:13px;margin:6px;font-size:16px}pre{white-space:pre-wrap;background:#24314b;padding:14px;border-radius:12px}h1{font-size:27px}</style>
<h1>Dav Launcher Â· Web Lab</h1><p>×©×¨×ª HTTP ×ž×§×•×ž×™ â€” × ×™×¡×•×™ 120 ×©× ×™×•×ª</p><button onclick="ping()">×‘×“×•×§ ×—×™×‘×•×¨</button><button onclick="logs()">×”×¦×’ ×™×•×ž×Ÿ</button><button onclick="count++;document.querySelector('#counter').textContent=count">×œ×—×¦×Ÿ ××™× ×˜×¨××§×˜×™×‘×™</button>
<p>×œ×—×™×¦×•×ª: <b id="counter">0</b></p><pre id="result">×ž×ž×ª×™×Ÿ...</pre>
<script>let count=0;async function ping(){try{let r=await fetch('/health?x='+Date.now());document.querySelector('#result').textContent=await r.text()}catch(e){document.querySelector('#result').textContent='FAILED: '+e}}async function logs(){try{document.querySelector('#result').textContent=await(await fetch('/log?x='+Date.now())).text()}catch(e){document.querySelector('#result').textContent='FAILED: '+e}}setInterval(ping,10000);ping()</script></html>
"""#
}

struct StartWebLabIntent: AppIntent {
    static let title: LocalizedStringResource = "LAB Start Local Web Server"
    static var description = IntentDescription("Start a 120-second localhost HTTP experiment with a Live Activity if supported.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            try WebLabServer.shared.start()
            WebLabLog.write("AppIntent invoked; requesting Live Activity")
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                do {
                    _ = try Activity<WebLabActivityAttributes>.request(
                        attributes: WebLabActivityAttributes(startedAt: Date()),
                        content: ActivityContent(state: .init(status: "Testing localhost:8765"), staleDate: Date().addingTimeInterval(120)),
                        pushType: nil)
                    WebLabLog.write("Live Activity request succeeded")
                } catch {
                    WebLabLog.write("Live Activity request failed: \(error)")
                }
            } else {
                WebLabLog.write("Live Activity unavailable or disabled")
            }
            return .result(value: "http://127.0.0.1:8765/")
        } catch {
            WebLabLog.write("server start error: \(error)")
            return .result(value: "ERROR: \(error)")
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

