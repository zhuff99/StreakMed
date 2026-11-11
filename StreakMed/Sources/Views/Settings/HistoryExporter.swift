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
            let dose   = csvEscape(log.medication?.doseLabel ?? "")
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
                let dose = log.medication?.doseLabel ?? "—"
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

    // MARK: - Adherence report

    static func makeAdherenceReport(_ report: MedicationStore.AdherenceReport) -> URL? {
        let dateFmt   = DateFormatter(); dateFmt.dateStyle   = .medium
        let exportFmt = DateFormatter(); exportFmt.dateStyle = .long

        var rows = ""
        for m in report.meds.sorted(by: { $0.percent > $1.percent }) {
            let cls = m.percent >= 90 ? "good" : (m.percent >= 70 ? "ok" : "low")
            rows += """
            <tr><td class="name">\(m.name)</td><td class="dose">\(m.dose)</td>
            <td class="num">\(m.taken) / \(m.scheduled)</td>
            <td class="num \(cls)">\(m.scheduled > 0 ? "\(m.percent)%" : "—")</td></tr>
            """
        }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          body  { font-family: -apple-system, Helvetica Neue, Helvetica; margin: 36px; color: #111; }
          h1    { font-size: 17px; font-weight: 700; margin: 0 0 3px; }
          .sub  { font-size: 11px; color: #777; margin-bottom: 18px; }
          .tiles { display: flex; gap: 10px; margin-bottom: 20px; }
          .tile { flex: 1; border: 1px solid #e3e3e3; border-radius: 8px; padding: 10px 12px; }
          .tile .v { font-size: 20px; font-weight: 700; }
          .tile .l { font-size: 10px; color: #777; text-transform: uppercase; letter-spacing: 0.4px; }
          table { width: 100%; border-collapse: collapse; font-size: 11px; }
          th    { text-align: left; padding: 4px 8px; background: #f0f0f0;
                  font-size: 10px; font-weight: 600; color: #555;
                  text-transform: uppercase; letter-spacing: 0.4px; }
          td    { padding: 5px 8px; border-bottom: 1px solid #eee; }
          .name { font-weight: 500; }
          .dose { color: #555; }
          .num  { text-align: right; }
          th.num { text-align: right; }
          .good { color: #1a7a4a; font-weight: 600; }
          .ok   { color: #b8870f; font-weight: 600; }
          .low  { color: #c0392b; font-weight: 600; }
          .note { font-size: 9px; color: #999; margin-top: 16px; }
        </style>
        </head>
        <body>
          <h1>StreakMed — Adherence Report</h1>
          <p class="sub">\(dateFmt.string(from: report.start)) – \(dateFmt.string(from: report.end)) · Exported \(exportFmt.string(from: Date()))</p>
          <div class="tiles">
            <div class="tile"><div class="v">\(report.percent)%</div><div class="l">Overall adherence</div></div>
            <div class="tile"><div class="v">\(report.taken) / \(report.scheduled)</div><div class="l">Doses taken</div></div>
            <div class="tile"><div class="v">\(report.perfectDays) / \(report.countedDays)</div><div class="l">Perfect days</div></div>
            <div class="tile"><div class="v">\(report.missedDays)</div><div class="l">Days fully missed</div></div>
          </div>
          <table>
            <tr><th>Medication</th><th>Dose</th><th class="num">Taken / Scheduled</th><th class="num">Adherence</th></tr>
            \(rows)
          </table>
          <p class="note">Counts only days each medication was scheduled, from the day it was added. Days marked as skipped in the app are excluded. Generated on-device by StreakMed.</p>
        </body>
        </html>
        """

        guard let data = renderHTMLtoPDF(html: html) else { return nil }
        return writeTempFile(name: "StreakMed_Adherence_Report.pdf", data: data)
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
