import SwiftUI

public extension Color {
    static let msAccent = Color.accentColor
    static let msSafe = Color.green
    static let msCaution = Color.orange
    static let msHighRisk = Color.red
    static let msBackground = Color(nsColor: .windowBackgroundColor)
    static let msSecondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let msLabel = Color(nsColor: .labelColor)
    static let msSecondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let msSeparator = Color(nsColor: .separatorColor)

    /// Create a Color from a 6-character hex string (e.g. "007AFF").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
