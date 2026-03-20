import SwiftUI

struct MedCard: View {
    let med: Medication
    let doseIndex: Int              // which dose this card represents
    @Binding var justTakenID: UUID?
    let onTake: (() -> Void)?       // nil = already taken / read-only

    @EnvironmentObject var store: MedicationStore

    @State private var showNotesPopover = false

    private var isTaken:  Bool   { store.isTaken(med, doseIndex: doseIndex) }
    private var isTaking: Bool   { justTakenID == med.id }   // true for ~0.5 s while the take animation plays
    private var medColor: Color  { Color(hex: med.color ?? "4FFFB0") }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 14) {
            colorDot
            info
            actionView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isTaken ? AppTheme.surface.opacity(0.5) : AppTheme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .opacity(isTaken ? 0.65 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isTaken)
    }

    // MARK: - Subviews

    private var colorDot: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isTaken ? AppTheme.surfaceAlt : medColor.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isTaken ? AppTheme.border : medColor.opacity(0.4), lineWidth: 1.5)
            )
            .overlay(
                Circle()
                    .fill(isTaken ? AppTheme.textDim : medColor)
                    .frame(width: 10, height: 10)
            )
            .frame(width: 40, height: 40)
    }

    private var info: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(med.name ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isTaken ? AppTheme.textMuted : AppTheme.text)
                    .strikethrough(isTaken, color: AppTheme.textMuted)

                // Line 1: dose · time (never wraps)
                Text(subtitleLine1)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textDim)
                    .lineLimit(1)

                // Line 2: "Dose N of M" badge — only for multi-dose meds
                if let doseLabel = doseIndexLabel {
                    Text(doseLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.surfaceAlt)
                        .cornerRadius(5)
                }
            }

            Spacer(minLength: 4)

            if let notes = med.notes, !notes.isEmpty {
                Button {
                    showNotesPopover = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "note.text")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.textDim)
                        Text(notes)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                            .frame(maxWidth: 90, alignment: .leading)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.surfaceAlt)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotesPopover, arrowEdge: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textDim)
                                Text("Note")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Text(notes)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.text)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                    }
                    .frame(width: 260)
                    .frame(maxHeight: 200)
                    .background(AppTheme.surface)
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    // "500 mg · 08:00"  or  "500 mg · Taken at 8:02 AM"
    private var subtitleLine1: String {
        let dose = med.dose ?? ""
        if isTaken, let t = store.takenTime(med, doseIndex: doseIndex) {
            return "\(dose) · Taken at \(formatted(t))"
        }
        let times = med.doseTimesArray
        let doseTime = doseIndex < times.count ? times[doseIndex] : med.scheduledTime
        let scheduled = doseTime.map { formatted($0) } ?? ""
        return "\(dose) · \(scheduled)"
    }

    // "Dose 1 of 2" — only for multi-dose meds
    private var doseIndexLabel: String? {
        let times = med.doseTimesArray
        guard times.count > 1 else { return nil }
        return "Dose \(doseIndex + 1) of \(times.count)"
    }

    @ViewBuilder
    private var actionView: some View {
        if isTaken {
            Circle()
                .fill(AppTheme.accentDim)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                )
                .frame(width: 28, height: 28)
        } else if let onTake = onTake {
            Button(action: onTake) {
                Text(isTaking ? "✓" : "Take")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(minWidth: 52)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentDim)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1.5)
                    )
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .scaleEffect(isTaking ? 1.06 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isTaking)
        }
    }

    // MARK: - Helpers

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
