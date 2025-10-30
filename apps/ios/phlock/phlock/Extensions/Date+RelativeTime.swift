import Foundation

extension Date {
    /// Returns a relative time string like "5 minutes ago", "2 hours ago", "yesterday", etc.
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns a short relative time string like "5m ago", "2h ago", "1d ago"
    func shortRelativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
