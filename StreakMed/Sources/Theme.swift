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

/// All colours resolve dynamically from the active `AppPalette` and the current
/// UITraitCollection, so they adapt to light/dark and to a theme switch the
/// next time they're drawn. Views keep reading `AppTheme.bg`, `AppTheme.accent`, ….
struct AppTheme {

    /// Active theme. Written only on the main thread by Settings (`ThemePicker`).
    nonisolated(unsafe) static var palette: AppPalette = AppPalette.stored

    private static func dynamic(_ key: KeyPath<Palette, String>) -> Color {
        Color(UIColor { traits in
            let p = traits.userInterfaceStyle == .dark ? palette.dark : palette.light
            return UIColor(hex: p[keyPath: key])
        })
    }

    // ── Backgrounds ──────────────────────────────────────────────────
    static var bg:         Color { dynamic(\.bg) }
    static var surface:    Color { dynamic(\.surface) }
    static var surfaceAlt: Color { dynamic(\.surfaceAlt) }
    static var border:     Color { dynamic(\.border) }

    // ── Accent ───────────────────────────────────────────────────────
    static var accent:     Color { dynamic(\.accent) }
    static var accentDim:  Color { dynamic(\.accentDim) }
    static var accentText: Color { dynamic(\.accentText) }
    static var accentFG:   Color { dynamic(\.accentFG) }

    // ── Blue ─────────────────────────────────────────────────────────
    static var blue:       Color { dynamic(\.blue) }
    static var blueDim:    Color { dynamic(\.blueDim) }

    // ── Warning (orange) ─────────────────────────────────────────────
    static var warn:       Color { dynamic(\.warn) }
    static var warnDim:    Color { dynamic(\.warnDim) }

    // ── Missed (red) ─────────────────────────────────────────────────
    static var missed:     Color { dynamic(\.missed) }
    static var missedDim:  Color { dynamic(\.missedDim) }

    // ── Text ─────────────────────────────────────────────────────────
    static var text:       Color { dynamic(\.text) }
    static var textMuted:  Color { dynamic(\.textMuted) }
    static var textDim:    Color { dynamic(\.textDim) }

    // ── Partial (gold) ───────────────────────────────────────────────
    static var partial:    Color { dynamic(\.partial) }
}

// MARK: - Themes

/// One mode's worth of hex values for every AppTheme slot.
struct Palette {
    let bg, surface, surfaceAlt, border: String
    let accent, accentDim, accentText, accentFG: String
    let blue, blueDim, warn, warnDim, missed, missedDim: String
    let text, textMuted, textDim, partial: String
}

/// Full app themes. Each has its own light and dark palette; the user's
/// Light / System / Dark choice still picks between them.
/// Raw values are persisted under `storageKey` — never rename a case.
enum AppPalette: String, CaseIterable, Identifiable {
    case midnight, ink, forest, graphite

    static let storageKey = "appPalette"

    var id: String { rawValue }

    static var stored: AppPalette {
        AppPalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .midnight
    }

    var name: String {
        switch self {
        case .midnight: return "Midnight"
        case .ink:      return "Ink"
        case .forest:   return "Forest"
        case .graphite: return "Graphite"
        }
    }

    var dark: Palette {
        switch self {
        case .midnight:
            return Palette(bg: "0F1117", surface: "1A1D27", surfaceAlt: "22263A", border: "2A2F45",
                           accent: "4FFFB0", accentDim: "1A3D2E", accentText: "3DD68C", accentFG: "0A1A12",
                           blue: "5B8BFF", blueDim: "1A2340", warn: "FF7A50", warnDim: "3D1F15",
                           missed: "FF4F4F", missedDim: "3D1212",
                           text: "F0F2FF", textMuted: "7B80A0", textDim: "4A4F6A", partial: "FFD166")
        case .ink:
            return Palette(bg: "0F0E16", surface: "1A1825", surfaceAlt: "242136", border: "2E2A44",
                           accent: "B69CFF", accentDim: "2A2342", accentText: "A68BFF", accentFG: "140F24",
                           blue: "6E9BFF", blueDim: "1B2442", warn: "FF7A50", warnDim: "3D1F15",
                           missed: "FF5C6C", missedDim: "3D141A",
                           text: "F1EFFF", textMuted: "8580A3", textDim: "4E4A68", partial: "FFD166")
        case .forest:
            return Palette(bg: "161513", surface: "201E1B", surfaceAlt: "2A2824", border: "35322D",
                           accent: "7BC59A", accentDim: "23332A", accentText: "8FD3AC", accentFG: "0F1A13",
                           blue: "7AA2E0", blueDim: "1E2633", warn: "E08A5E", warnDim: "3A241A",
                           missed: "E5675F", missedDim: "3A1A17",
                           text: "F1ECE3", textMuted: "9C958A", textDim: "5E584F", partial: "E3B15C")
        case .graphite:
            return Palette(bg: "111111", surface: "1C1C1E", surfaceAlt: "2A2A2C", border: "323234",
                           accent: "64D2FF", accentDim: "15303B", accentText: "4EC2F2", accentFG: "06171F",
                           blue: "7B9CFF", blueDim: "1C2236", warn: "FF8A50", warnDim: "3B2015",
                           missed: "FF5F57", missedDim: "3A1716",
                           text: "F2F2F2", textMuted: "9A9A9E", textDim: "5A5A5E", partial: "FFD166")
        }
    }

    var light: Palette {
        switch self {
        case .midnight:
            return Palette(bg: "F2F3F8", surface: "FFFFFF", surfaceAlt: "EAECF2", border: "D4D7E2",
                           accent: "34D88F", accentDim: "E0F8ED", accentText: "28A96A", accentFG: "FFFFFF",
                           blue: "4A7AEE", blueDim: "E5ECFF", warn: "E86840", warnDim: "FFF0EB",
                           missed: "E63E3E", missedDim: "FFECEC",
                           text: "1A1D27", textMuted: "6B7085", textDim: "A0A4B8", partial: "E6B84D")
        case .ink:
            return Palette(bg: "F5F4FA", surface: "FFFFFF", surfaceAlt: "EDEBF6", border: "DCD8EC",
                           accent: "8B6CF0", accentDim: "EEE9FD", accentText: "6E4FD8", accentFG: "FFFFFF",
                           blue: "4A7AEE", blueDim: "E5ECFF", warn: "E86840", warnDim: "FFF0EB",
                           missed: "E0394D", missedDim: "FDE9EC",
                           text: "1D1B29", textMuted: "6D6889", textDim: "A9A5BF", partial: "E6B84D")
        case .forest:
            return Palette(bg: "F6F3EE", surface: "FFFFFF", surfaceAlt: "EFEAE2", border: "E2DCD1",
                           accent: "2F7D5B", accentDim: "E3EFE8", accentText: "2F7D5B", accentFG: "FFFFFF",
                           blue: "3E6FB0", blueDim: "E4ECF6", warn: "C4572E", warnDim: "FBEBE3",
                           missed: "C23B3B", missedDim: "FAE6E4",
                           text: "1F2420", textMuted: "6F6A60", textDim: "A8A196", partial: "C98A2B")
        case .graphite:
            return Palette(bg: "F2F2F4", surface: "FFFFFF", surfaceAlt: "E9E9EC", border: "D8D8DC",
                           accent: "1E9BD7", accentDim: "E1F3FC", accentText: "1580B5", accentFG: "FFFFFF",
                           blue: "4A7AEE", blueDim: "E5ECFF", warn: "E86840", warnDim: "FFF0EB",
                           missed: "E5484D", missedDim: "FDECEC",
                           text: "1C1C1E", textMuted: "6E6E73", textDim: "A8A8AD", partial: "E6B84D")
        }
    }
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
    "4FFFB0", "5B8BFF", "FF7A50", "C97BFF", "FFD166", "FF4F4F", "64D2FF"
]
