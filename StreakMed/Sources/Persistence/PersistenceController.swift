import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // MARK: - Preview (in-memory store with sample data)
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext

        let samples: [(name: String, dose: String, type: String, color: String, hour: Int)] = [
            ("Lisinopril",     "10mg",   "Heart",       "4FFFB0", 8),
            ("Metformin",      "500mg",  "Diabetes",    "5B8BFF", 8),
            ("Atorvastatin",   "20mg",   "Cholesterol", "FF7A50", 12),
            ("Levothyroxine",  "50mcg",  "Thyroid",     "C97BFF", 18),
            ("Aspirin",        "81mg",   "Heart",       "FFD166", 21),
        ]

        for (i, s) in samples.enumerated() {
            let med = Medication(context: ctx)
            med.id             = UUID()
            med.name           = s.name
            med.dose           = s.dose
            med.type           = s.type
            med.color          = s.color
            med.isActive       = true
            med.createdAt      = Date()
            med.notificationID = UUID().uuidString
            med.sortOrder      = Int32(i)

            var comps = DateComponents()
            comps.hour   = s.hour
            comps.minute = 0
            med.scheduledTime = Calendar.current.date(from: comps) ?? Date()

            // Mark the first two as taken today for preview
            if i < 2 {
                let log = DoseLog(context: ctx)
                log.id            = UUID()
                log.medication    = med
                log.takenAt       = Date()
                log.scheduledDate = Calendar.current.startOfDay(for: Date())
                log.status        = "taken"
            }
        }

        try? ctx.save()
        return result
    }()

    // MARK: - Container
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "StreakMed")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, handle gracefully instead of fatalError
                fatalError("CoreData load error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
