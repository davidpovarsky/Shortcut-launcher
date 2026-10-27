import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

enum ObjectTypeLabSamples {
    static func vCards() -> [IntentFile] {
        let people: [(String, String, String)] = [
            ("Daniel Cohen", "daniel@example.com", "+12025550101"),
            ("Sarah Levy", "sarah@example.com", "+12025550102"),
            ("Yosef Israeli", "yosef@example.com", "+12025550103")
        ]
        return people.enumerated().map { index, person in
            let lines = [
                "BEGIN:VCARD",
                "VERSION:3.0",
                "N:;\(person.0);;;",
                "FN:\(person.0)",
                "EMAIL;TYPE=INTERNET:\(person.1)",
                "TEL;TYPE=CELL:\(person.2)",
                "NOTE:Standalone sample contact for Shortcuts Object Type Lab",
                "END:VCARD"
            ]
            return IntentFile(
                data: Data((lines.joined(separator: "\r\n") + "\r\n").utf8),
                filename: "Demo-Contact-\(index + 1).vcf",
                type: UTType(filenameExtension: "vcf")
            )
        }
    }

    @MainActor
    static func pngImages() -> [IntentFile] {
        let samples: [(String, UIColor, String)] = [
            ("Blue-Home", .systemBlue, "house.fill"),
            ("Gold-Star", .systemYellow, "star.fill"),
            ("Green-Plus", .systemGreen, "plus.circle.fill")
        ]
        return samples.map { sample in
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
            let data = renderer.pngData { _ in
                let bounds = CGRect(x: 0, y: 0, width: 256, height: 256)
                sample.1.setFill()
                UIBezierPath(roundedRect: bounds, cornerRadius: 42).fill()
                let icon = UIImage(systemName: sample.2,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 125, weight: .medium))
                icon?.withTintColor(.white, renderingMode: .alwaysOriginal)
                    .draw(in: CGRect(x: 65, y: 65, width: 126, height: 126))
            }
            return IntentFile(data: data, filename: "\(sample.0).png", type: .png)
        }
    }

    static func calendarEvents() -> [IntentFile] {
        let samples = [
            ("Team-Meeting", "Team Meeting", "20271101T090000Z", "20271101T100000Z"),
            ("Design-Review", "Design Review", "20271102T130000Z", "20271102T140000Z"),
            ("Project-Demo", "Project Demo", "20271103T150000Z", "20271103T160000Z")
        ]
        return samples.enumerated().map { index, item in
            let data = [
                "BEGIN:VCALENDAR",
                "VERSION:2.0",
                "PRODID:-//DavLauncher//ObjectTypeLab//EN",
                "BEGIN:VEVENT",
                "UID:lab-event-\(index)@davlauncher.example",
                "DTSTAMP:20261027T120000Z",
                "DTSTART:\(item.2)",
                "DTEND:\(item.3)",
                "SUMMARY:\(item.1)",
                "DESCRIPTION:Standalone demonstration calendar event file",
                "END:VEVENT",
                "END:VCALENDAR",
                ""
            ].joined(separator: "\r\n")
            return IntentFile(data: Data(data.utf8), filename: "\(item.0).ics",
                              type: UTType(filenameExtension: "ics"))
        }
    }

    static func reminderTasks() -> [IntentFile] {
        let names = ["Read the report", "Send feedback", "Review the design"]
        return names.enumerated().map { index, name in
            let data = [
                "BEGIN:VCALENDAR",
                "VERSION:2.0",
                "PRODID:-//DavLauncher//ObjectTypeLab//EN",
                "BEGIN:VTODO",
                "UID:lab-task-\(index)@davlauncher.example",
                "DTSTAMP:20261027T120000Z",
                "SUMMARY:\(name)",
                "STATUS:NEEDS-ACTION",
                "END:VTODO",
                "END:VCALENDAR",
                ""
            ].joined(separator: "\r\n")
            return IntentFile(data: Data(data.utf8), filename: "Task-\(index + 1).ics",
                              type: UTType(filenameExtension: "ics"))
        }
    }

    static func textFiles() -> [IntentFile] {
        ["Notes", "Checklist", "Instructions"].map { name in
            IntentFile(
                data: Data("Object Type Lab - \(name)\nSample content for file previews.\n".utf8),
                filename: "\(name).txt",
                type: .plainText
            )
        }
    }

    @MainActor
    static func pdfFiles() -> [IntentFile] {
        ["Overview", "Report", "Invitation"].map { name in
            let page = CGRect(x: 0, y: 0, width: 595, height: 842)
            let renderer = UIGraphicsPDFRenderer(bounds: page)
            let data = renderer.pdfData { context in
                context.beginPage()
                let titleStyle: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 36),
                    .foregroundColor: UIColor.black
                ]
                (name as NSString).draw(
                    at: CGPoint(x: 50, y: 80), withAttributes: titleStyle
                )
                let subtitle = "Object Type Lab - native PDF file example"
                (subtitle as NSString).draw(
                    at: CGPoint(x: 50, y: 150),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 17)]
                )
            }
            return IntentFile(data: data, filename: "\(name).pdf", type: .pdf)
        }
    }

    static func audioSamples(music: Bool) -> [IntentFile] {
        [440.0, 523.25, 659.25].enumerated().map { index, frequency in
            let count = 22050
            var samples = Data(capacity: count * 2)
            for i in 0..<count {
                let phase = 2.0 * Double.pi * frequency * Double(i) / 22050.0
                let value = Int16((sin(phase) * 7000).rounded())
                var little = value.littleEndian
                withUnsafeBytes(of: &little) { samples.append(contentsOf: $0) }
            }
            let size = UInt32(samples.count)
            var bytes = Data()
            bytes.append(contentsOf: Array("RIFF".utf8))
            appendLE(size + 36, to: &bytes)
            bytes.append(contentsOf: Array("WAVEfmt ".utf8))
            appendLE(UInt32(16), to: &bytes)
            appendLE(UInt16(1), to: &bytes)
            appendLE(UInt16(1), to: &bytes)
            appendLE(UInt32(22050), to: &bytes)
            appendLE(UInt32(44100), to: &bytes)
            appendLE(UInt16(2), to: &bytes)
            appendLE(UInt16(16), to: &bytes)
            bytes.append(contentsOf: Array("data".utf8))
            appendLE(size, to: &bytes)
            bytes.append(samples)
            return IntentFile(
                data: bytes,
                filename: "\(music ? "Music" : "Audio")-Tone-\(index + 1).wav",
                type: UTType(filenameExtension: "wav")
            )
        }
    }

    static func videoFiles() -> [IntentFile] {
        (1...3).compactMap { index in
            let name = "Lab-Video-\(index)"
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp4"),
                  let data = try? Data(contentsOf: url) else {
                return nil
            }
            return IntentFile(data: data, filename: "\(name).mp4",
                              type: UTType(filenameExtension: "mp4"))
        }
    }

    @MainActor
    static func formattedTexts() -> [AttributedString] {
        ["Bold sample text", "Italic sample text", "Underlined sample text"]
            .enumerated().map { index, value in
                var text = AttributedString(value)
                if index == 0 { text.font = .boldSystemFont(ofSize: 20) }
                if index == 1 { text.font = .italicSystemFont(ofSize: 18) }
                if index == 2 { text.underlineStyle = .single }
                return text
            }
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
