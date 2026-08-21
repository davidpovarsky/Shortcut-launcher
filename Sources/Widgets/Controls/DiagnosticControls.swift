import SwiftUI
import WidgetKit

struct DiagnosticWidgetPingControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.diagnostic.widgetPing"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DiagnosticWidgetPingIntent()) {
                Label("Widget Ping", systemImage: "wave.3.right")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : "Widget Ping",
                    systemImage: isPerforming ? "hourglass" : "wave.3.right"
                )
            }
        }
        .displayName("LAB: Widget Ping")
        .description("Proves whether a plain AppIntent executes in the WidgetKit extension.")
    }
}

struct DiagnosticMainPingControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.diagnostic.mainPing"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DiagnosticMainPingIntent()) {
                Label("Main Ping", systemImage: "app.badge.checkmark")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Running" : "Main Ping",
                    systemImage: isPerforming ? "hourglass" : "app.badge.checkmark"
                )
            }
        }
        .displayName("LAB: Main Ping")
        .description("Proves whether Control Center can route a plain AppIntent to the main app process.")
    }
}

struct DiagnosticWidgetNotificationControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.diagnostic.widgetNotification"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DiagnosticWidgetNotificationIntent()) {
                Label("Widget Notification", systemImage: "bell.badge")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Sending" : "Widget Notification",
                    systemImage: isPerforming ? "hourglass" : "bell.badge"
                )
            }
        }
        .displayName("LAB: Widget Notification")
        .description("Schedules a fixed local notification directly from the WidgetKit extension.")
    }
}

struct DiagnosticMainNotificationControl: ControlWidget {
    static let kind = "com.dav.DavLauncher.diagnostic.mainNotification"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DiagnosticMainNotificationIntent()) {
                Label("Main Notification", systemImage: "bell.and.waves.left.and.right")
            } actionLabel: { isPerforming in
                Label(
                    isPerforming ? "Sending" : "Main Notification",
                    systemImage: isPerforming ? "hourglass" : "bell.and.waves.left.and.right"
                )
            }
        }
        .displayName("LAB: Main Notification")
        .description("Schedules a fixed local notification from the main app process.")
    }
}
