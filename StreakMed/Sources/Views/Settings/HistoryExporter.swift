import UIKit
import CoreData

/// Generates CSV and PDF exports of the user's full dose history.
/// Both formats write to a temp file and return the URL for sharing
/// via UIActivityViewController.
struct HistoryExporter {

    // MARK: - CSV

    static func makeCSV(context: NSManagedObjectContext) -> URL? {
        let logs = fetchAllLogs(context: context)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        var rows = ["Date,Medication,Dose,Time Taken,Status"]
        for log in logs {
            let date   = log.scheduledDate.map { dateFmt.string(from: $0) } ?? ""
            let name   = csvEscape(log.medication?.name ?? "Unknown")
            let dose   = csvEscape(log.medication?.dose ?? "")
            let time   = log.takenAt.map { timeFmt.string(from: $0) } ?? ""
            let status = log.status ?? ""
            rows.append("\(date),\(name),\(dose),\(time),\(status)")
        }

        let csv = rows.joined(separator: "\n")
        return writeTempFile(name: "StreakMed_History.csv", data: Data(csv.utf8))
    }

    // MARK: - PDF

    static func makePDF(context: NSManagedObjectContext) -> URL? {
        let logs = fetchAllLogs(context: context)

        let dateFmt   = DateFormatter(); dateFmt.dateFormat   = "MMMM d, yyyy"
        let timeFmt   = DateFormatter(); timeFmt.dateFormat   = "h:mm a"
        let exportFmt = DateFormatter(); exportFmt.dateStyle  = .long

        // Group logs by their scheduledDate string
        var groups: [(header: String, logs: [DoseLog])] = []
        var bucket: [DoseLog] = []
        var currentKey = ""
        for log in logs {
            let key = log.scheduledDate.map { dateFmt.string(from: $0) } ?? "Unknown Date"
            if key != currentKey {
                if !bucket.isEmpty { groups.append((currentKey, bucket)) }
                currentKey = key
                bucket = [log]
            } else {
                bucket.append(log)
            }
        }
        if !bucket.isEmpty { groups.append((currentKey, bucket)) }

        // Build HTML
        var tableRows = ""
        for group in groups {
            tableRows += """
            <tr class="date-row"><td colspan="3">\(group.header)</td></tr>
            """
            for log in group.logs {
                let name = log.medication?.name ?? "Unknown"
                let dose = log.medication?.dose ?? "—"
                let time = log.takenAt.map { timeFmt.string(from: $0) } ?? "—"
                tableRows += "<tr><td class=\"name\">\(name)</td><td class=\"dose\">\(dose)</td><td class=\"time\">\(time)</td></tr>"
            }
        }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          body  { font-family: -apple-system, Helvetica Neue, Helvetica; margin: 36px; color: #111; }
          h1    { font-size: 17px; font-weight: 700; margin: 0 0 3px; }
          .sub  { font-size: 11px; color: #777; margin-bottom: 16px; }
          table { width: 100%; border-collapse: collapse; font-size: 11px; }
          th    { text-align: left; padding: 4px 8px; background: #f0f0f0;
                  font-size: 10px; font-weight: 600; color: #555;
                  text-transform: uppercase; letter-spacing: 0.4px; }
          td    { padding: 3px 8px; border-bottom: 1px solid #eee; }
          tr.date-row td { background: #f7f7f7; font-size: 10px; font-weight: 600;
                           color: #444; padding: 5px 8px; border-top: 1px solid #ddd; }
          .name { font-weight: 500; }
          .dose { color: #555; }
          .time { color: #1a7a4a; font-weight: 500; }
        </style>
        </head>
        <body>
          <h1>StreakMed — Medication History</h1>
          <p class="sub">Exported \(exportFmt.string(from: Date()))</p>
          <table>
            <tr><th>Medication</th><th>Dose</th><th>Time Taken</th></tr>
            \(tableRows)
          </table>
        </body>
        </html>
        """

        guard let data = renderHTMLtoPDF(html: html) else { return nil }
        return writeTempFile(name: "StreakMed_History.pdf", data: data)
    }

    // MARK: - Private helpers

    private static func fetchAllLogs(context: NSManagedObjectContext) -> [DoseLog] {
        let req: NSFetchRequest<DoseLog> = DoseLog.fetchRequest()
        req.predicate = NSPredicate(format: "status == %@", "taken")
        req.sortDescriptors = [
            NSSortDescriptor(key: "scheduledDate", ascending: true),
            NSSortDescriptor(key: "takenAt",       ascending: true)
        ]
        return (try? context.fetch(req)) ?? []
    }

    /// Wraps a field in quotes and escapes any internal quotes.
    private static func csvEscape(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Renders an HTML string to a US-Letter PDF using UIKit's print formatters.
    private static func renderHTMLtoPDF(html: String) -> Data? {
        let renderer  = UIPrintPageRenderer()
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageSize    = CGSize(width: 612, height: 792)          // US Letter
        let printable   = CGRect(x: 36, y: 36, width: 540, height: 720)
        renderer.setValue(NSValue(cgRect: CGRect(origin: .zero, size: pageSize)), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable),                              forKey: "printableRect")

        let buffer = NSMutableData()
        UIGraphicsBeginPDFContextToData(buffer, CGRect(origin: .zero, size: pageSize), nil)
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return buffer as Data
    }

    /// Writes data to the temp directory and returns the file URL.
    private static func writeTempFile(name: String, data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("[StreakMed] Export write error: \(error)")
            return nil
        }
    }
}
