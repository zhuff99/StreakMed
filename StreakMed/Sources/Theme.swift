import SwiftUI

// MARK: - UIColor hex helper (private, used only by AppTheme)

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

// MARK: - App Theme

/// All colours resolve dynamically based on the current UITraitCollection,
/// so they automatically adapt whenever preferredColorScheme changes.
struct AppTheme {

    /// Creates a SwiftUI Color that resolves to `dark` hex in dark mode
    /// and `light` hex in light mode.
    private static func dynamic(dark: String, light: String) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // ── Backgrounds ──────────────────────────────────────────────────
    static var bg:         Color { dynamic(dark: "0F1117", light: "F2F3F8") }
    static var surface:    Color { dynamic(dark: "1A1D27", light: "FFFFFF") }
    static var surfaceAlt: Color { dynamic(dark: "22263A", light: "EAECF2") }
    static var border:     Color { dynamic(dark: "2A2F45", light: "D4D7E2") }

    // ── Accent (mint green) ──────────────────────────────────────────
    static var accent:     Color { dynamic(dark: "4FFFB0", light: "34D88F") }
    static var accentDim:  Color { dynamic(dark: "1A3D2E", light: "E0F8ED") }
    static var accentText: Color { dynamic(dark: "3DD68C", light: "28A96A") }
    static var accentFG:   Color { dynamic(dark: "0A1A12", light: "FFFFFF") }

    // ── Blue ─────────────────────────────────────────────────────────
    static var blue:       Color { dynamic(dark: "5B8BFF", light: "4A7AEE") }
    static var blueDim:    Color { dynamic(dark: "1A2340", light: "E5ECFF") }

    // ── Warning (orange) ─────────────────────────────────────────────
    static var warn:       Color { dynamic(dark: "FF7A50", light: "E86840") }
    static var warnDim:    Color { dynamic(dark: "3D1F15", light: "FFF0EB") }

    // ── Missed (red) ─────────────────────────────────────────────────
    static var missed:     Color { dynamic(dark: "FF4F4F", light: "E63E3E") }
    static var missedDim:  Color { dynamic(dark: "3D1212", light: "FFECEC") }

    // ── Text ─────────────────────────────────────────────────────────
    static var text:       Color { dynamic(dark: "F0F2FF", light: "1A1D27") }
    static var textMuted:  Color { dynamic(dark: "7B80A0", light: "6B7085") }
    static var textDim:    Color { dynamic(dark: "4A4F6A", light: "A0A4B8") }

    // ── Partial (yellow) ─────────────────────────────────────────────
    static var partial:    Color { dynamic(dark: "FFD166", light: "E6B84D") }
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
