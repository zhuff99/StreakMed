import UIKit

/// How a medication is taken: drives the icon on cards/rows, the quantity
/// wording ("2 tablets", "1 scoop", "3 puffs"), and the supply label.
/// Stored on Medication.shape as the raw string; nil (pre-existing meds)
/// falls back to .capsule. Raw values are persisted — never rename one.
enum PillShape: String, CaseIterable, Identifiable {
    case capsule
    case tablet
    case oval
    case gummy
    case powder
    case liquid
    case drops
    case inhaler
    case spray
    case injection
    case patch
    case cream

    var id: String { rawValue }

    /// Pill-like forms keep the compact "10 mg" dose display for a single unit.
    var isPill: Bool { self == .capsule || self == .tablet || self == .oval || self == .gummy }

    var icon: String {
        let symbol = preferredSymbol
        return UIImage(systemName: symbol) != nil ? symbol : "pills.fill"
    }

    private var preferredSymbol: String {
        switch self {
        // Two-tone horizontal capsule — reads instantly as a gel cap
        case .capsule:   return "capsule.lefthalf.filled"
        // Ring with filled center — the classic scored-tablet look
        case .tablet:    return "smallcircle.filled.circle.fill"
        // Vertical oval — softgel silhouette, distinct from the capsule
        case .oval:      return "oval.portrait.fill"
        case .gummy:     return "seal.fill"
        case .powder:    return "cup.and.saucer.fill"
        case .liquid:    return "drop.fill"
        case .drops:     return "eyedropper.halffull"
        case .inhaler:   return "inhaler.fill"
        case .spray:     return "wind"
        case .injection: return "syringe.fill"
        case .patch:     return "bandage.fill"
        case .cream:     return "hands.sparkles.fill"
        }
    }

    var label: String {
        switch self {
        case .capsule:   return "Capsule"
        case .tablet:    return "Tablet"
        case .oval:      return "Softgel"
        case .gummy:     return "Gummy"
        case .powder:    return "Powder"
        case .liquid:    return "Liquid"
        case .drops:     return "Drops"
        case .inhaler:   return "Inhaler"
        case .spray:     return "Spray"
        case .injection: return "Injection"
        case .patch:     return "Patch"
        case .cream:     return "Cream"
        }
    }

    /// The countable unit for one dose: "1 scoop", "2 puffs".
    func noun(_ count: Int) -> String {
        let one = count == 1
        switch self {
        case .capsule:   return one ? "capsule"     : "capsules"
        case .tablet:    return one ? "tablet"      : "tablets"
        case .oval:      return one ? "softgel"     : "softgels"
        case .gummy:     return one ? "gummy"       : "gummies"
        case .powder:    return one ? "scoop"       : "scoops"
        case .liquid:    return one ? "dose"        : "doses"
        case .drops:     return one ? "drop"        : "drops"
        case .inhaler:   return one ? "puff"        : "puffs"
        case .spray:     return one ? "spray"       : "sprays"
        case .injection: return one ? "injection"   : "injections"
        case .patch:     return one ? "patch"       : "patches"
        case .cream:     return one ? "application" : "applications"
        }
    }

    /// Field label for the optional supply count, e.g. "Scoops on Hand".
    var supplyLabel: String { noun(2).capitalized + " on Hand" }

    static func from(_ raw: String?) -> PillShape {
        PillShape(rawValue: raw ?? "") ?? .capsule
    }
}
