import Foundation

/// One medication from the bundled RxTerms dataset.
struct MedDBEntry: Decodable, Identifiable, Hashable {
    let n: String       // display name, e.g. "Lisinopril"
    let s: [String]     // strengths, e.g. ["2.5 mg", "5 mg", "10 mg"]
    let f: String       // most common dose form, e.g. "Tab"

    var id: String { n }
    var name: String { n }
    var strengths: [String] { s }

    /// Human-readable form for the suggestion row caption.
    var formLabel: String {
        switch f {
        case "Tab":  return "Tablet"
        case "Cap":  return "Capsule"
        case "Sol":  return "Solution"
        case "Susp": return "Suspension"
        case "":     return ""
        default:     return f
        }
    }

    /// Splits a strength like "10 mg" / "2.5 mg/ml" / "5%" / "1-10%" into
    /// AddMedSheet's amount + unit fields. Returns nil when it doesn't parse,
    /// in which case no chip should be shown for that strength.
    func doseComponents(for strength: String) -> (amount: String, unit: String)? {
        let pattern = #"^([\d,]+(?:\.\d+)?(?:\s*-\s*[\d,]+(?:\.\d+)?)?)\s*(mg|mcg|g|ml|iu|units?|%)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: strength, range: NSRange(strength.startIndex..., in: strength)),
              let amountRange = Range(match.range(at: 1), in: strength),
              let unitRange   = Range(match.range(at: 2), in: strength)
        else { return nil }
        let amount = String(strength[amountRange])
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        var unit = String(strength[unitRange]).lowercased()
        if unit == "ml" { unit = "mL" }
        if unit == "iu" { unit = "IU" }
        if unit == "unit" { unit = "units" }
        return (amount, unit)
    }

    /// Strengths that parse into dose fields — only these get chips.
    var tappableStrengths: [String] {
        s.filter { doseComponents(for: $0) != nil }
    }
}

/// Offline medication name autocomplete backed by the public-domain RxTerms
/// dataset (U.S. National Library of Medicine), bundled as meds_db.json.
/// ~7,800 prescribable drugs; everything runs on-device.
enum MedDatabase {

    private static var entries: [MedDBEntry] = []
    private static var loadStarted = false

    /// Kicks off the one-time background load. Call early (e.g. when the
    /// Add-Med sheet appears) so results are ready by the first keystroke.
    static func preload() {
        guard !loadStarted else { return }
        loadStarted = true
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url  = Bundle.main.url(forResource: "meds_db", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let list = try? JSONDecoder().decode([MedDBEntry].self, from: data)
            else { return }
            DispatchQueue.main.async { entries = list }
        }
    }

    /// Case-insensitive search: prefix matches rank above substring matches.
    static func search(_ query: String, limit: Int = 6) -> [MedDBEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2, !entries.isEmpty else { return [] }

        var prefix:   [MedDBEntry] = []
        var contains: [MedDBEntry] = []
        for entry in entries {
            let lower = entry.n.lowercased()
            if lower.hasPrefix(q) {
                prefix.append(entry)
            } else if lower.contains(q) {
                contains.append(entry)
            }
            if prefix.count >= limit { break }
        }
        return Array((prefix + contains).prefix(limit))
    }
}
