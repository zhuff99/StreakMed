import SwiftUI

// MARK: - Day picker helper

struct WeekdayItem: Identifiable {
    let id:      Int    // Calendar.weekday (1=Sun … 7=Sat)
    let label:   String
}

let weekdayItems: [WeekdayItem] = [
    .init(id: 1, label: "S"),
    .init(id: 2, label: "M"),
    .init(id: 3, label: "T"),
    .init(id: 4, label: "W"),
    .init(id: 5, label: "T"),
    .init(id: 6, label: "F"),
    .init(id: 7, label: "S"),
]

// MARK: - Dose Time Picker Sheet (shared)

struct DoseTimePickerSheet: View {
    let doseNumber: Int
    @Binding var time: Date
    let onDone:   () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text("Dose \(doseNumber) Time")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                Spacer()
                Button("Done", action: onDone)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .colorScheme(.dark)

            Spacer()
        }
        .background(AppTheme.surface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - AddMedSheet

struct AddMedSheet: View {
    /// name, dose (e.g. "10 mg"), type, color hex, scheduledTimes, scheduledDays, pillsRemaining, notes
    let onSave: (String, String, String, String, [Date], Set<Int>, Int?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name:           String   = ""
    @State private var doseAmount:     String   = ""
    @State private var doseUnit:       String   = "mg"
    @State private var quantity:       Int      = 1
    @State private var pillsOnHand:    String   = ""
    @State private var notes:          String   = ""
    @State private var type:           String   = "General"
    @State private var selectedColor:  String   = "4FFFB0"
    @State private var customColor:    Color    = Color(hex: "4FFFB0")
    @State private var showColorPicker: Bool    = false
    @State private var scheduledTimes:  [Date]   = [AddMedSheet.defaultTime()]
    @State private var selectedDays:    Set<Int> = Set(1...7)
    @State private var editingDoseIndex: Int?    = nil
    @State private var tempDoseTime:     Date    = Date()
    @State private var showScanner:      Bool    = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let notesLimit = 100
    private let maxDoses   = 4

    private static func defaultTime() -> Date {
        Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    }

    private let typeOptions = [
        "General", "Heart", "Blood Pressure", "Diabetes",
        "Cholesterol", "Thyroid", "Mental Health", "Pain Relief", "Other"
    ]

    private let doseUnits = [
        "mg", "mcg", "g", "mL", "L", "IU",
        "units", "tablets", "capsules", "drops", "patch", "puffs"
    ]

    /// Save button is enabled only when the two required fields are filled and at least one day is selected.
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !doseAmount.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedDays.isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Name ─────────────────────────────────────────────
                    FormTextField(label: "Medication Name", placeholder: "e.g. Lisinopril", text: $name)

                    // ── Dose amount + unit ────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("Dose")
                        HStack(spacing: 10) {
                            // Amount field
                            TextField("Amount", text: $doseAmount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.text)
                                .padding(14)
                                .background(AppTheme.surfaceAlt)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                                .frame(width: 110)

                            // Unit picker
                            Menu {
                                ForEach(doseUnits, id: \.self) { unit in
                                    Button(unit) { doseUnit = unit }
                                }
                            } label: {
                                HStack {
                                    Text(doseUnit)
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.text)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                .padding(14)
                                .background(AppTheme.surfaceAlt)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // ── Quantity per dose ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("Quantity per Dose")
                        Menu {
                            ForEach(1...10, id: \.self) { n in
                                Button("\(n) \(n == 1 ? "pill" : "pills")") { quantity = n }
                            }
                        } label: {
                            HStack {
                                Text("\(quantity) \(quantity == 1 ? "pill" : "pills")")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.text)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding(14)
                            .background(AppTheme.surfaceAlt)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        }
                    }

                    // ── Notes (optional) ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            FieldLabel("Notes")
                            Text("optional")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.surfaceAlt)
                                .cornerRadius(4)
                            Spacer()
                            Text("\(notes.count)/\(notesLimit)")
                                .font(.system(size: 10))
                                .foregroundColor(notes.count > notesLimit - 10 ? AppTheme.missed : AppTheme.textDim)
                        }
                        TextField("e.g. Take with food, avoid grapefruit", text: $notes, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.text)
                            .padding(14)
                            .background(AppTheme.surfaceAlt)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                            .onChange(of: notes) { newVal in
                                if newVal.count > notesLimit { notes = String(newVal.prefix(notesLimit)) }
                            }
                    }

                    // ── Pills on hand (optional) ─────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            FieldLabel("Pills on Hand")
                            Text("optional")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.surfaceAlt)
                                .cornerRadius(4)
                        }
                        TextField("e.g. 30", text: $pillsOnHand)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.text)
                            .padding(14)
                            .background(AppTheme.surfaceAlt)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    }

                    // ── Days of week ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        FieldLabel("Schedule Days")
                        HStack(spacing: 6) {
                            ForEach(weekdayItems) { item in
                                let active = selectedDays.contains(item.id)
                                Button {
                                    if active {
                                        // Keep at least one day selected
                                        if selectedDays.count > 1 {
                                            selectedDays.remove(item.id)
                                        }
                                    } else {
                                        selectedDays.insert(item.id)
                                    }
                                } label: {
                                    Text(item.label)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(active ? AppTheme.accentFG : AppTheme.textMuted)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(active ? AppTheme.accent : AppTheme.surfaceAlt)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    active ? Color.clear : AppTheme.border,
                                                    lineWidth: 1
                                                )
                                        )
                                }
                            }
                        }
                        // Quick-select row — centered
                        HStack(spacing: 10) {
                            Spacer()
                            quickSelectButton(label: "Every day") {
                                selectedDays = Set(1...7)
                            }
                            quickSelectButton(label: "Weekdays") {
                                selectedDays = Set([2, 3, 4, 5, 6])
                            }
                            quickSelectButton(label: "Weekends") {
                                selectedDays = Set([1, 7])
                            }
                            Spacer()
                        }
                        .padding(.top, 2)
                    }

                    // ── Category ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel("Category")
                        Menu {
                            ForEach(typeOptions, id: \.self) { option in
                                Button(option) { type = option }
                            }
                        } label: {
                            HStack {
                                Text(type)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.text)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding(14)
                            .background(AppTheme.surfaceAlt)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        }
                    }

                    // ── Color picker ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        FieldLabel("Color")
                        HStack(spacing: 14) {
                            ForEach(medColorPalette, id: \.self) { hex in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedColor = hex
                                        showColorPicker = false
                                    }
                                } label: {
                                    let isSelected = selectedColor == hex && !showColorPicker
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                        .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 0))
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: hex), lineWidth: 5)
                                                .scaleEffect(isSelected ? 1.28 : 0)
                                                .opacity(isSelected ? 1 : 0)
                                        )
                                }
                            }
                            // Color wheel button — opens system picker directly on first tap
                            ColorPicker(selection: $customColor, supportsOpacity: false) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            AngularGradient(
                                                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                                center: .center
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                    Circle()
                                        .fill(Color.black.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "eyedropper")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .overlay(Circle().stroke(Color.white, lineWidth: showColorPicker ? 3 : 0))
                                .overlay(
                                    Circle()
                                        .stroke(customColor, lineWidth: 5)
                                        .scaleEffect(showColorPicker ? 1.28 : 0)
                                        .opacity(showColorPicker ? 1 : 0)
                                )
                            }
                            .labelsHidden()
                            .onChange(of: customColor) { newColor in
                                if let hex = newColor.toHex() {
                                    selectedColor = hex
                                    showColorPicker = true
                                }
                            }
                            Spacer()
                        }
                    }

                    // ── Doses per Day ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            FieldLabel("Doses per Day")
                            Spacer()
                            HStack(spacing: 0) {
                                Button {
                                    if scheduledTimes.count > 1 { scheduledTimes.removeLast() }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(scheduledTimes.count > 1 ? AppTheme.text : AppTheme.textDim)
                                        .frame(width: 36, height: 36)
                                        .background(AppTheme.surfaceAlt)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                                        .cornerRadius(8)
                                }
                                Text("\(scheduledTimes.count)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.text)
                                    .frame(width: 36)
                                Button {
                                    if scheduledTimes.count < maxDoses {
                                        // Default next dose 6 hours after last
                                        let last = scheduledTimes.last ?? AddMedSheet.defaultTime()
                                        let next = Calendar.current.date(byAdding: .hour, value: 6, to: last) ?? last
                                        scheduledTimes.append(next)
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(scheduledTimes.count < maxDoses ? AppTheme.text : AppTheme.textDim)
                                        .frame(width: 36, height: 36)
                                        .background(AppTheme.surfaceAlt)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        if scheduledTimes.count == 1 {
                            // Single dose — keep the familiar wheel inline
                            DatePicker("", selection: $scheduledTimes[0], displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .colorScheme(.dark)
                        } else {
                            // Multiple doses — compact tappable rows, each opens its own sheet
                            VStack(spacing: 8) {
                                ForEach(scheduledTimes.indices, id: \.self) { i in
                                    Button {
                                        tempDoseTime = scheduledTimes[i]
                                        editingDoseIndex = i
                                    } label: {
                                        HStack {
                                            HStack(spacing: 8) {
                                                Image(systemName: "clock.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(AppTheme.textMuted)
                                                Text("Dose \(i + 1)")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(AppTheme.textMuted)
                                            }
                                            Spacer()
                                            Text(shortTime(scheduledTimes[i]))
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppTheme.text)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(AppTheme.textDim)
                                                .padding(.leading, 2)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 13)
                                        .background(AppTheme.surfaceAlt)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .sheet(isPresented: Binding(
                        get: { editingDoseIndex != nil },
                        set: { if !$0 { editingDoseIndex = nil } }
                    )) {
                        if let idx = editingDoseIndex {
                            DoseTimePickerSheet(
                                doseNumber: idx + 1,
                                time: $tempDoseTime,
                                onDone: {
                                    scheduledTimes[idx] = tempDoseTime
                                    editingDoseIndex = nil
                                },
                                onCancel: { editingDoseIndex = nil }
                            )
                            .presentationDetents([.height(300)])
                            .presentationDragIndicator(.visible)
                        }
                    }

                    // ── Save ──────────────────────────────────────────────
                    Button {
                        let amount = doseAmount.trimmingCharacters(in: .whitespaces)
                        let combinedDose = quantity > 1
                            ? "\(quantity) × \(amount) \(doseUnit)"
                            : "\(amount) \(doseUnit)"
                        let pills = pillsOnHand.trimmingCharacters(in: .whitespaces).isEmpty
                            ? nil : Int(pillsOnHand.trimmingCharacters(in: .whitespaces))
                        let notesVal = notes.trimmingCharacters(in: .whitespaces)
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            combinedDose,
                            type,
                            selectedColor,
                            scheduledTimes,
                            selectedDays,
                            pills,
                            notesVal.isEmpty ? nil : notesVal
                        )
                        dismiss()
                    } label: {
                        Text("Save Medication")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isValid ? AppTheme.accentFG : AppTheme.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? AppTheme.accent : AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isValid ? Color.clear : AppTheme.border, lineWidth: 1)
                            )
                            .cornerRadius(16)
                    }
                    .disabled(!isValid)
                }
                .padding(24)
                .frame(maxWidth: sizeClass == .regular ? 640 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle("New Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Scan")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                PrescriptionScannerSheet { info in
                    applyScannedResult(info)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    /// Fills the form with the structured data returned by the prescription scanner.
    /// Only overwrites fields that the scanner actually found — existing user input is preserved
    /// for anything the scanner didn't return. Dose times are spaced evenly across the day
    /// starting from the scanner's suggested hour (e.g. 3 doses per day → 8 AM, 16 PM, 0 AM).
    private func applyScannedResult(_ info: ScannedMedInfo) {
        if !info.name.isEmpty        { name = info.name }
        if !info.doseAmount.isEmpty  { doseAmount = info.doseAmount }
        if doseUnits.contains(info.doseUnit) { doseUnit = info.doseUnit }
        if typeOptions.contains(info.type)   { type = info.type }
        if let pills = info.pillCount        { pillsOnHand = "\(pills)" }
        if !info.notes.isEmpty { notes = String(info.notes.prefix(notesLimit)) }

        // Space dose times evenly through the day (e.g. 3 doses → every 8 hours)
        let cal   = Calendar.current
        let count = min(max(info.dosesPerDay, 1), maxDoses)
        let gap   = count > 1 ? (24 / count) : 0
        scheduledTimes = (0..<count).compactMap { i in
            let hour = (info.scheduledHour + i * gap) % 24
            return cal.date(from: DateComponents(hour: hour, minute: 0))
        }
    }

    // MARK: - Quick select button

    @ViewBuilder
    private func quickSelectButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.surfaceAlt)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
        }
    }
}
