import Foundation

/// All the text formatting the UI needs, in one place so views stay logic-free.
nonisolated enum TimeFormat {
    /// 134 → "2:14", 3725 → "1:02:05"
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// 113 → "−1:53"
    static func remaining(_ seconds: TimeInterval) -> String {
        "\u{2212}" + clock(seconds)
    }

    /// 7440 → "2 h 4 min", 3480 → "58 min"
    static func summary(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        guard minutes >= 60 else { return "\(max(minutes, 0)) min" }
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func fileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func count(_ number: Int, _ singular: String, plural: String? = nil) -> String {
        "\(number) \(number == 1 ? singular : (plural ?? singular + "s"))"
    }
}
