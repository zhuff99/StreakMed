import Foundation

/// Visual form of a medication, shown on dose cards, med rows, and pickers.
/// Stored on Medication.shape as the raw string; nil (pre-existing meds)
/// falls back to .capsule.
enum PillShape: String, CaseIterable, Identifiable {
    case capsule
    case tablet
    case oval
    case liquid
    case injection
    case inhaler

    var id: String { rawValue }

    var icon: String {
        switch self {
        // Two-tone horizontal capsule — reads instantly as a gel cap
        case .capsule:   return "capsule.lefthalf.filled"
        // Ring with filled center — the classic scored-tablet look
        case .tablet:    return "smallcircle.filled.circle.fill"
        // Vertical oval — softgel silhouette, distinct from the capsule
        case .oval:      return "oval.portrait.fill"
        case .liquid:    return "drop.fill"
        case .injection: return "syringe.fill"
        case .inhaler:   return "inhaler.fill"
        }
    }

    var label: String {
        switch self {
        case .capsule:   return "Capsule"
        case .tablet:    return "Tablet"
        case .oval:      return "Oval"
        case .liquid:    return "Liquid"
        case .injection: return "Injection"
        case .inhaler:   return "Inhaler"
        }
    }

    static func from(_ raw: String?) -> PillShape {
        PillShape(rawValue: raw ?? "") ?? .capsule
    }
}
