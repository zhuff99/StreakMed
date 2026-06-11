import SwiftUI
import HealthKit

// MARK: - Import candidate

/// One medication read from Apple Health, parsed into StreakMed's fields.
struct HealthMedCandidate: Identifiable {
    let id = UUID()
    let name: String
    let dose: String          // e.g. "10 mg", or "" if not parseable
    let alreadyExists: Bool   // a med with this name is already in StreakMed
}

// MARK: - Health import logic (iOS 26+)

@available(iOS 26.0, *)
enum HealthMedImporter {

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access to the user's Health medication list and returns
    /// active (non-archived) medications parsed into import candidates.
    static func fetchCandidates(existingNames: Set<String>) async throws -> [HealthMedCandidate] {
        let store = HKHealthStore()
        try await store.requestAuthorization(
            toShare: [],
            read: [HKObjectType.userAnnotatedMedicationType()]
        )

        let meds = try await HKUserAnnotatedMedicationQueryDescriptor().result(for: store)

        return meds
            .filter { !$0.isArchived }
            .map { med in
                let raw = med.nickname?.isEmpty == false
                    ? med.nickname!
                    : med.medication.displayText
                let (name, dose) = parse(raw)
                return HealthMedCandidate(
                    name: name,
                    dose: dose,
                    alreadyExists: existingNames.contains(name.lowercased())
                )
            }
    }

    /// Splits Health's display text (e.g. "Lisinopril 10 MG Oral Tablet")
    /// into a clean name and a dose string. Falls back to the full text.
    static func parse(_ text: String) -> (name: String, dose: String) {
        let pattern = #"(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|iu|units?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let amountRange = Range(match.range(at: 1), in: text),
              let unitRange   = Range(match.range(at: 2), in: text),
              let fullRange   = Range(match.range, in: text)
        else {
            return (text.trimmingCharacters(in: .whitespaces), "")
        }

        let unit = text[unitRange].lowercased() == "ml" ? "mL" : String(text[unitRange]).lowercased()
        let dose = "\(text[amountRange]) \(unit)"
        let name = String(text[..<fullRange.lowerBound])
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
        return (name.isEmpty ? text : name, dose)
    }
}

// MARK: - Import sheet

@available(iOS 26.0, *)
struct HealthImportSheet: View {
    @EnvironmentObject private var store: MedicationStore
    @Environment(\.dismiss) private var dismiss

    @State private var candidates:  [HealthMedCandidate] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var isLoading    = true
    @State private var loadError:   String? = nil

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(AppTheme.accent)
                        Text("Reading your medications from Apple Health…")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 44))
                            .foregroundColor(AppTheme.textDim)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if candidates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 44))
                            .foregroundColor(AppTheme.textDim)
                        Text("No medications found in Apple Health.\nAdd them in the Health app, or add meds here manually.")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    candidateList
                }
            }
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle("Import from Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .task { await load() }
    }

    private var candidateList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("Imported medications get a daily 8:00 AM reminder — tap any med afterwards to set its real schedule.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }

            Button {
                importSelected()
            } label: {
                Text(selectedIDs.isEmpty
                     ? "Select medications to import"
                     : "Import \(selectedIDs.count) Medication\(selectedIDs.count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(selectedIDs.isEmpty ? AppTheme.textDim : AppTheme.accentFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedIDs.isEmpty ? AppTheme.surfaceAlt : AppTheme.accent)
                    .cornerRadius(16)
            }
            .disabled(selectedIDs.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func candidateRow(_ candidate: HealthMedCandidate) -> some View {
        let isSelected = selectedIDs.contains(candidate.id)
        Button {
            guard !candidate.alreadyExists else { return }
            if isSelected { selectedIDs.remove(candidate.id) }
            else          { selectedIDs.insert(candidate.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: candidate.alreadyExists
                      ? "checkmark.circle"
                      : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 22))
                    .foregroundColor(candidate.alreadyExists
                                     ? AppTheme.textDim
                                     : (isSelected ? AppTheme.accent : AppTheme.textDim))
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(candidate.alreadyExists ? AppTheme.textDim : AppTheme.text)
                    Text(candidate.alreadyExists
                         ? "Already in StreakMed"
                         : (candidate.dose.isEmpty ? "Dose not detected" : candidate.dose))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }
            .padding(14)
            .background(AppTheme.surfaceAlt)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.border, lineWidth: 1)
            )
        }
        .disabled(candidate.alreadyExists)
    }

    private func load() async {
        let existing = Set(store.medications.compactMap { $0.name?.lowercased() })
        do {
            let found = try await HealthMedImporter.fetchCandidates(existingNames: existing)
            candidates  = found
            selectedIDs = Set(found.filter { !$0.alreadyExists }.map(\.id))
            isLoading   = false
        } catch {
            loadError = "Couldn't read from Apple Health. Check that StreakMed has access in Settings → Health → Data Access."
            isLoading = false
        }
    }

    private func importSelected() {
        let cal = Calendar.current
        let eightAM = cal.date(bySettingHour: 8, minute: 0, second: 0,
                               of: DebugDateManager.shared.currentDate) ?? Date()

        for (i, candidate) in candidates.enumerated() where selectedIDs.contains(candidate.id) {
            store.addMedication(
                name:  candidate.name,
                dose:  candidate.dose,
                type:  "General",
                color: medColorPalette[i % medColorPalette.count],
                scheduledTimes: [eightAM]
            )
        }
        dismiss()
    }
}
