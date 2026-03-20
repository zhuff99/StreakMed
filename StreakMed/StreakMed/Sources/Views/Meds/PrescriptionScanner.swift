import SwiftUI
import Vision
import PhotosUI

// MARK: - Scanned Result

/// Structured data returned by the prescription scanner after OCR + Claude AI parsing.
/// All fields have safe defaults so partial results still populate the form meaningfully.
struct ScannedMedInfo {
    var name:          String = ""
    var doseAmount:    String = ""
    var doseUnit:      String = "mg"
    var type:          String = "General"
    var pillCount:     Int?   = nil
    var dosesPerDay:   Int    = 1
    var scheduledHour: Int    = 8
    var notes:         String = ""

    init() {}

    init(from dict: [String: Any]) {
        name          = dict["name"]          as? String ?? ""
        doseAmount    = dict["doseAmount"]    as? String ?? ""
        doseUnit      = dict["doseUnit"]      as? String ?? "mg"
        type          = dict["type"]          as? String ?? "General"
        pillCount     = dict["pillCount"]     as? Int
        dosesPerDay   = dict["dosesPerDay"]   as? Int    ?? 1
        scheduledHour = dict["scheduledHour"] as? Int    ?? 8
        notes         = dict["notes"]         as? String ?? ""
    }
}

// MARK: - Scanner Sheet

struct PrescriptionScannerSheet: View {
    let onResult: (ScannedMedInfo) -> Void
    @Environment(\.dismiss) private var dismiss

    @AppStorage("claudeApiKey") private var apiKey: String = ""

    @State private var selectedImage:   UIImage? = nil
    @State private var showPhotoPicker: Bool     = false
    @State private var showCamera:      Bool     = false
    @State private var isScanning:      Bool     = false
    @State private var scanError:       String?  = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                // ── API key warning ────────────────────────────────────
                if apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.partial)
                            .font(.system(size: 14))
                        Text("Add your Claude API key in Settings to enable scanning.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(12)
                    .background(AppTheme.surfaceAlt)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                }

                // ── Image preview ──────────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.surfaceAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(16)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 52))
                                .foregroundColor(AppTheme.textDim)
                            Text("Take or choose a photo of\nyour prescription label")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .padding(.horizontal, 24)

                // ── Source buttons ─────────────────────────────────────
                HStack(spacing: 12) {
                    sourceButton(icon: "camera.fill", label: "Camera") {
                        showCamera = true
                    }
                    sourceButton(icon: "photo.on.rectangle", label: "Photo Library") {
                        showPhotoPicker = true
                    }
                }
                .padding(.horizontal, 24)

                // ── Error message ──────────────────────────────────────
                if let error = scanError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.missed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // ── Tip ────────────────────────────────────────────────
                Text("For best results, ensure the label is flat, well-lit, and fully in frame.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // ── Scan button ────────────────────────────────────────
                let canScan = selectedImage != nil && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    guard let image = selectedImage else { return }
                    scanImage(image)
                } label: {
                    HStack(spacing: 8) {
                        if isScanning {
                            ProgressView()
                                .tint(AppTheme.accentFG)
                        } else {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text(isScanning ? "Scanning…" : "Scan Label")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(canScan ? AppTheme.accentFG : AppTheme.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canScan ? AppTheme.accent : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(canScan ? Color.clear : AppTheme.border, lineWidth: 1)
                    )
                    .cornerRadius(16)
                }
                .disabled(!canScan || isScanning)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle("Scan Prescription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerRepresentable(image: $selectedImage)
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerRepresentable(image: $selectedImage)
        }
    }

    // MARK: - Source button helper

    @ViewBuilder
    private func sourceButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.surfaceAlt)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Vision OCR → Claude API

    /// Two-step scan pipeline:
    /// 1. Apple Vision runs on-device OCR to extract raw text lines from the image.
    /// 2. The raw text is sent to Claude (claude-haiku) which returns a structured JSON
    ///    object that maps cleanly onto the AddMedSheet form fields.
    private func scanImage(_ image: UIImage) {
        isScanning = true
        scanError  = nil

        guard let cgImage = image.cgImage else {
            scanError  = "Could not process this image."
            isScanning = false
            return
        }

        let key = apiKey.trimmingCharacters(in: .whitespaces)

        // Step 1: Vision OCR — runs on a background thread
        let ocrRequest = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanError  = "Text recognition failed: \(error.localizedDescription)"
                }
                return
            }

            // Each VNRecognizedTextObservation is a text region; topCandidates(1) gives
            // the highest-confidence string for that region.
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }

            guard !lines.isEmpty else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanError  = "No text found. Try a clearer, well-lit photo."
                }
                return
            }

            let labelText = lines.joined(separator: "\n")

            // Step 2: Hand raw OCR text to Claude for intelligent structured parsing
            ClaudeParser.parse(text: labelText, apiKey: key) { result, parseError in
                DispatchQueue.main.async {
                    self.isScanning = false
                    if let parseError = parseError {
                        self.scanError = parseError.localizedDescription
                        return
                    }
                    if let result = result {
                        self.onResult(result)
                        self.dismiss()
                    }
                }
            }
        }
        ocrRequest.recognitionLevel       = .accurate   // slower but much more accurate than .fast
        ocrRequest.usesLanguageCorrection = true        // fixes common OCR typos using a language model

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([ocrRequest])
        }
    }
}

// MARK: - Claude API Parser

struct ClaudeParser {

    private static let endpoint = "https://api.anthropic.com/v1/messages"
    private static let model    = "claude-haiku-4-5-20251001"

    static func parse(text: String,
                      apiKey: String,
                      completion: @escaping (ScannedMedInfo?, Error?) -> Void) {

        guard let url = URL(string: endpoint) else {
            completion(nil, err("Invalid API endpoint.")); return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")

        let prompt = """
        You are parsing text extracted from a prescription medicine label via OCR. \
        Extract the medication details and return ONLY a valid JSON object — no markdown, no explanation, nothing else.

        Return exactly this shape:
        {
          "name": "medication name only, no strength",
          "doseAmount": "numeric value as string, e.g. \\"10\\"",
          "doseUnit": "one of: mg, mcg, g, mL, IU, units",
          "type": "one of: General, Heart, Blood Pressure, Diabetes, Cholesterol, Thyroid, Mental Health, Pain Relief, Other",
          "pillCount": 30,
          "dosesPerDay": 1,
          "scheduledHour": 8,
          "notes": "patient directions line, or empty string"
        }

        Rules:
        - name: brand or generic name only, strip strength (e.g. "Lisinopril" not "Lisinopril 10mg")
        - scheduledHour: 8=morning, 12=noon, 18=evening, 21=bedtime (use 24h integer)
        - dosesPerDay: infer from directions (once daily=1, twice daily=2, TID=3, QID=4)
        - pillCount: integer from Qty/Quantity field, or null if not present
        - notes: copy the patient directions line verbatim if present, otherwise ""

        Prescription label text:
        \(text)
        """

        let body: [String: Any] = [
            "model":      model,
            "max_tokens": 512,
            "messages":   [["role": "user", "content": prompt]]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, err("Failed to build request.")); return
        }
        req.httpBody = bodyData

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(nil, err("Network error: \(error.localizedDescription)")); return
            }

            // Check HTTP status
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
                if http.statusCode == 401 {
                    completion(nil, err("Invalid API key. Check Settings.")); return
                }
                completion(nil, err("API error \(http.statusCode): \(detail)")); return
            }

            guard let data = data,
                  let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content  = envelope["content"] as? [[String: Any]],
                  let rawText  = content.first?["text"] as? String
            else {
                completion(nil, err("Unexpected API response format.")); return
            }

            // Claude is instructed to return pure JSON, but as a safety net we
            // find the first '{' and last '}' to strip any accidental preamble/postamble.
            let jsonString: String
            if let start = rawText.firstIndex(of: "{"),
               let end   = rawText.lastIndex(of:  "}") {
                jsonString = String(rawText[start...end])
            } else {
                completion(nil, err("AI did not return valid JSON.")); return
            }

            guard let jsonData   = jsonString.data(using: .utf8),
                  let parsedDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                completion(nil, err("Could not parse AI response.")); return
            }

            completion(ScannedMedInfo(from: parsedDict), nil)
        }.resume()
    }

    private static func err(_ msg: String) -> Error {
        NSError(domain: "StreakMed.Scanner", code: 0,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

// MARK: - PHPicker wrapper

/// SwiftUI wrapper around PHPickerViewController for selecting a photo from the library.
/// PHPicker doesn't require NSPhotoLibraryUsageDescription — it uses a built-in system picker.
struct PHPickerRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter         = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerRepresentable
        init(_ parent: PHPickerRepresentable) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async { self.parent.image = object as? UIImage }
            }
        }
    }
}

// MARK: - Camera wrapper

/// SwiftUI wrapper around UIImagePickerController for capturing a photo with the camera.
/// Falls back to the photo library if the device has no camera (e.g. simulators).
/// Requires NSCameraUsageDescription in Info.plist.
struct CameraPickerRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerRepresentable
        init(_ parent: CameraPickerRepresentable) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            parent.image = info[.originalImage] as? UIImage
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
