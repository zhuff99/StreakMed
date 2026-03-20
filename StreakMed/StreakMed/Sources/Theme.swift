import SwiftUI

// MARK: - App Theme
// All design tokens extracted from the StreakMed mockup.
// Use AppTheme.xxx everywhere — never hardcode hex colors inline.

struct AppTheme {
    // Backgrounds
    static let bg          = Color(hex: "0F1117")
    static let surface     = Color(hex: "1A1D27")
    static let surfaceAlt  = Color(hex: "22263A")
    static let border      = Color(hex: "2A2F45")

    // Accent (mint green)
    static let accent      = Color(hex: "4FFFB0")
    static let accentDim   = Color(hex: "1A3D2E")
    static let accentText  = Color(hex: "3DD68C")
    static let accentFG    = Color(hex: "0A1A12")  // text on accent backgrounds

    // Blue
    static let blue        = Color(hex: "5B8BFF")
    static let blueDim     = Color(hex: "1A2340")

    // Warning (orange)
    static let warn        = Color(hex: "FF7A50")
    static let warnDim     = Color(hex: "3D1F15")

    // Missed (red)
    static let missed      = Color(hex: "FF4F4F")
    static let missedDim   = Color(hex: "3D1212")

    // Text
    static let text        = Color(hex: "F0F2FF")
    static let textMuted   = Color(hex: "7B80A0")
    static let textDim     = Color(hex: "4A4F6A")

    // Partial (yellow)
    static let partial     = Color(hex: "FFD166")
}

// MARK: - Color hex initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Converts a SwiftUI Color to a 6-character uppercase hex string, or nil if resolution fails.
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Shared small components

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppTheme.textMuted)
            .tracking(0.8)
    }
}

struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.textMuted)
    }
}

struct FormTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label)
            TextField(placeholder, text: $text)
                .foregroundColor(AppTheme.text)
                .font(.system(size: 15))
                .padding(14)
                .background(AppTheme.surfaceAlt)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Custom Toggle

struct StreakToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(configuration.isOn ? AppTheme.accent : AppTheme.surfaceAlt)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(configuration.isOn ? AppTheme.accent : AppTheme.border, lineWidth: 1)
            )
            .overlay(
                Circle()
                    .fill(configuration.isOn ? AppTheme.accentFG : AppTheme.textDim)
                    .frame(width: 18, height: 18)
                    .offset(x: configuration.isOn ? 9 : -9)
                    .animation(.easeInOut(duration: 0.18), value: configuration.isOn)
            )
            .frame(width: 44, height: 26)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    configuration.isOn.toggle()
                }
            }
    }
}

// MARK: - Color palette for med pills
let medColorPalette: [String] = [
    "4FFFB0", "5B8BFF", "FF7A50", "C97BFF", "FFD166", "FF4F4F"
]
