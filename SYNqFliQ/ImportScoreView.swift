//
//  ImportScoreView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/04.
//

//
//  ImportScoreView.swift
//  SYNqFliQ
//
//  SwiftUI view that collects score metadata, lets the user pick:
//  - an audio file
//  - a background image
//  - a thumbnail image
//  - a notes JSON file
//
//  It then assembles a combined score JSON (metadata + notes array), copies the picked files
//  into a per-user directory inside the app Documents folder, and writes the final <id>.json there.
//  Assumes you have an AuthManager (or similar) that exposes the current user id via
//  AuthManager.shared.firebaseUser?.uid — if not present, it falls back to "local-user".
//
//  Usage: present ImportScoreView() from your UI (sheet / navigation).
//

import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import FirebaseAuth
import AVFoundation

// MARK: - Models used only by this importer
fileprivate struct RawNote: Codable {
    var id: String
    var time: Double
    var angleDegrees: Double?
    var normalizedPosition: Position?
    var noteType: String? // optional, allow different shapes
    // permit other fields via coding keys if needed
}
fileprivate struct Position: Codable {
    var x: Double
    var y: Double
}

// 3) Replace the ExportScore struct definition with this (adds `author`)
fileprivate struct ExportScore: Codable {
    var version: Int = 1
    var title: String
    var composer: String
    var chapter: String
    var author: String? = nil
    var difficulty: String
    var level: Int
    var id: String
    var bpm: Double
    var audioFilename: String?
    var backgroundFilename: String?
    var thumbnailFilename: String?
    var notes: [RawNote]
}

// MARK: - Document Picker wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void

    init(contentTypes: [UTType],
         allowsMultipleSelection: Bool = false,
         onPick: @escaping ([URL]) -> Void) {
        self.contentTypes = contentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onPick = onPick
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = allowsMultipleSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onPick([])
        }
    }
}

// MARK: - ImportScoreView
struct ImportScoreView: View {
    var onClose: () -> Void = { }
    @Environment(\.presentationMode) var presentationMode

    // Inputs
    @State private var titleText: String = ""
    @State private var composerText: String = ""
    @State private var authorText: String = ""
    @State private var chapterText: String = ""
    @State private var difficultyText: String = ""
    @State private var levelText: String = ""
    @State private var idText: String = ""
    @State private var bpmText: String = ""

    // picked files (temporary URLs provided by UIDocumentPicker; we will copy them to app Documents)
    @State private var audioURL: URL? = nil
    @State private var backgroundURL: URL? = nil
    @State private var thumbnailURL: URL? = nil
    @State private var notesJSONURL: URL? = nil

    // UI states
    @State private var showPicker: Bool = false
    @State private var pickerTypes: [UTType] = []
    @State private var pickerHandler: (([URL]) -> Void)? = nil

    @State private var isImporting: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false

    // Provide a default folder in documents named for the user
    private var currentUserID: String {
        if let uid = AuthManager.shared.firebaseUser?.uid { return uid }
        return "local-user"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Metadata")) {
                    TextField("Title", text: $titleText)
                    TextField("Composer", text: $composerText)
                    TextField("Author", text: $authorText)
                    TextField("Chapter", text: $chapterText)
                    TextField("Difficulty", text: $difficultyText)
                    TextField("Level", text: $levelText)
                        .keyboardType(.numberPad)
                    TextField("ID", text: $idText)
                    TextField("BPM", text: $bpmText)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Files")) {
                    fileRow(label: "Audio", url: audioURL?.lastPathComponent) {
                        presentPicker(types: [UTType.audio, UTType.mp3, UTType.mpeg4Audio]) { urls in
                            self.audioURL = urls.first
                        }
                    }
                    fileRow(label: "Background image", url: backgroundURL?.lastPathComponent) {
                        presentPicker(types: [UTType.image]) { urls in
                            self.backgroundURL = urls.first
                        }
                    }
                    fileRow(label: "Thumbnail image", url: thumbnailURL?.lastPathComponent) {
                        presentPicker(types: [UTType.image]) { urls in
                            self.thumbnailURL = urls.first
                        }
                    }
                    fileRow(label: "Notes JSON", url: notesJSONURL?.lastPathComponent) {
                        presentPicker(types: [UTType.json, UTType(filenameExtension: "json")!]) { urls in
                            self.notesJSONURL = urls.first
                        }
                    }
                }
                
                Section {
                    Button(action: { doImport() }) {
                        HStack {
                            Spacer()
                            if isImporting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Import & Save").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isImporting)
                    .accessibility(identifier: "ImportSaveButton")
                }
                
                if let nurl = notesJSONURL {
                    Section(header: Text("Notes preview (first 5)")) {
                        NotesPreview(url: nurl)
                    }
                }
            }
            
            
           
            .navigationBarTitle("Import Score", displayMode: .inline)
            .navigationBarItems(leading: Button("Close"){ onClose() 
                presentationMode.wrappedValue.dismiss() })
            .fileImporterSupport(show: $showPicker, types: pickerTypes, onPick: pickerHandler)
            .alert(isPresented: $showAlert, content: {
                Alert(title: Text("Import"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
            })
        }
    }

    // small helper to render file row
    @ViewBuilder
    private func fileRow(label: String, url: String?, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label)
                if let u = url {
                    Text(u).font(.caption).foregroundColor(.secondary).lineLimit(1)
                } else {
                    Text("No file selected").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: action) {
                Text("Pick")
            }
        }
    }

    // Convenience: present UIDocumentPicker using our wrapper - preserves minimal code changes where used.
    private func presentPicker(types: [UTType], completion: @escaping ([URL]) -> Void) {
        pickerTypes = types
        pickerHandler = { urls in
            completion(urls)
            // reset
            DispatchQueue.main.async {
                pickerTypes = []
                pickerHandler = nil
            }
        }
        showPicker = true
    }

    // Main import flow
    private func doImport() {
        // Validation
        guard !titleText.trimmingCharacters(in: .whitespaces).isEmpty else { presentError("Title is required."); return }
        guard !composerText.trimmingCharacters(in: .whitespaces).isEmpty else { presentError("Composer is required."); return }
        guard !idText.trimmingCharacters(in: .whitespaces).isEmpty else { presentError("ID is required."); return }
        guard !bpmText.trimmingCharacters(in: .whitespaces).isEmpty, let bpm = Double(bpmText) else { presentError("BPM numeric required."); return }
        guard let notesURL = notesJSONURL else { presentError("Please pick a notes JSON file."); return }

        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // read notes JSON (either raw array or full object)
                let data = try Data(contentsOf: notesURL)
                // Try decode as an object that may already include metadata and notes
                if let maybeTop = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let notesAny = maybeTop["notes"] {
                    // If the JSON already contains 'notes' array, extract it and decode into RawNote[]
                    let notesArrayData = try JSONSerialization.data(withJSONObject: notesAny, options: [])
                    let notes = try JSONDecoder().decode([RawNote].self, from: notesArrayData)
                    try performSave(notes: notes, bpm: bpm)
                } else {
                    // If the JSON is just notes array
                    let notes = try JSONDecoder().decode([RawNote].self, from: data)
                    try performSave(notes: notes, bpm: bpm)
                }
            } catch {
                DispatchQueue.main.async {
                    self.presentError("Failed to import notes JSON: \(error.localizedDescription)")
                }
            }
        }
    }

    // saves files and writes combined JSON into user's directory
    // Replacement for the performSave(notes:bpm:) function in ImportScoreView.swift
    // Fixes the "use of local variable 'docs' before its declaration" errors by declaring FileManager and docs up-front,
    // ensures safeID/folder creation is consistent, and removes duplicate userFolder declarations.

    private func performSave(notes: [RawNote], bpm: Double) throws {
        // Prepare FileManager and Documents URL early so we can use them throughout
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        // Ensure idText is safe and unique: if folder exists, append -1, -2, ...
        let baseID = idText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : idText.trimmingCharacters(in: .whitespacesAndNewlines)
        var safeID = baseID
        var suffix = 1

        let scoresBase = docs.appendingPathComponent("Scores").appendingPathComponent(currentUserID)
        // ensure the Scores/<user> base exists
        try fm.createDirectory(at: scoresBase, withIntermediateDirectories: true, attributes: nil)

        while fm.fileExists(atPath: scoresBase.appendingPathComponent(safeID).path) {
            safeID = "\(baseID)-\(suffix)"
            suffix += 1
        }

        // create the folder for this sheet
        let userFolder = scoresBase.appendingPathComponent(safeID)
        try fm.createDirectory(at: userFolder, withIntermediateDirectories: true, attributes: nil)

        // Build ExportScore
        let levelValue = Int(levelText) ?? 0
        let export = ExportScore(
            version: 1,
            title: titleText,
            composer: composerText,
            chapter: chapterText,
            author: authorText,
            difficulty: difficultyText,
            level: levelValue,
            id: safeID,
            bpm: bpm,
            audioFilename: audioURL?.lastPathComponent,
            backgroundFilename: backgroundURL?.lastPathComponent,
            thumbnailFilename: thumbnailURL?.lastPathComponent,
            notes: notes
        )

        // Copy files into folder (audio/background/thumbnail). If filename collides, overwrite.
        if let a = audioURL {
            let dest = userFolder.appendingPathComponent(a.lastPathComponent)
            try copyToLocal(from: a, to: dest)
        }
        if let b = backgroundURL {
            let dest = userFolder.appendingPathComponent(b.lastPathComponent)
            try copyToLocal(from: b, to: dest)
        }
        if let t = thumbnailURL {
            let dest = userFolder.appendingPathComponent(t.lastPathComponent)
            try copyToLocal(from: t, to: dest)
        }

        // Write JSON to safeID.json
        let outURL = userFolder.appendingPathComponent("\(safeID).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(export)
        try jsonData.write(to: outURL, options: .atomic)

        // Update saved index using safeID as the key
        var savedIndex = UserDefaults.standard.dictionary(forKey: "SavedScores_\(currentUserID)") as? [String: String] ?? [:]
        savedIndex[safeID] = outURL.path
        UserDefaults.standard.setValue(savedIndex, forKey: "SavedScores_\(currentUserID)")

        // Refresh ScoreStore so UI picks up the newly imported sheet immediately
        ScoreStore.shared.refresh(for: currentUserID)

        DispatchQueue.main.async {
            // reflect the saved id back into the UI
            self.idText = safeID
            self.isImporting = false
            self.alertMessage = "Saved score \(self.titleText) as \(outURL.lastPathComponent)."
            self.showAlert = true
            // optionally close after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // Helper to copy a security-scoped or normal file URL into app folder
    private func copyToLocal(from src: URL, to dest: URL) throws {
        let fm = FileManager.default
        // if the src is a file provider (security-scoped), try startAccessingSecurityScopedResource
        var needsStop = false
        if src.startAccessingSecurityScopedResource() {
            needsStop = true
        }
        defer {
            if needsStop { src.stopAccessingSecurityScopedResource() }
        }

        // If src is on disk (we asked for copy when picking), simply copy/replace.
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: src, to: dest)
    }

    private func presentError(_ text: String) {
        DispatchQueue.main.async {
            self.isImporting = false
            self.alertMessage = text
            self.showAlert = true
        }
    }
}

// MARK: - Notes preview small helper
private struct NotesPreview: View {
    let url: URL
    @State private var items: [RawNote] = []
    var body: some View {
        Group {
            if items.isEmpty {
                Text("No preview").font(.caption)
            } else {
              
                ForEach(Array(items.prefix(5).enumerated()), id: \.1.id) { idx, n in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(n.id)").font(.caption).bold()
                        HStack {
                            
                            Text(String(format: "t=%.3f", n.time)).font(.caption2)
                            if let pos = n.normalizedPosition {
                                Text(String(format: "x=%.2f y=%.2f", pos.x, pos.y)).font(.caption2)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: url) { _ in load() }
    }

    private func load() {
        items = []
        do {
            let d = try Data(contentsOf: url)
            // support either top-level object with notes: [] or raw notes array
            if let maybeTop = try? JSONSerialization.jsonObject(with: d, options: []) as? [String: Any],
               let notesAny = maybeTop["notes"] {
                let notesData = try JSONSerialization.data(withJSONObject: notesAny, options: [])
                items = try JSONDecoder().decode([RawNote].self, from: notesData)
            } else {
                items = try JSONDecoder().decode([RawNote].self, from: d)
            }
        } catch {
            // ignore silently in preview
            print("NotesPreview load error: \(error)")
        }
    }
}

// MARK: - small ViewModifier to support our DocumentPicker approach using .sheet binding
private struct FileImporterSupport: ViewModifier {
    @Binding var show: Bool
    var types: [UTType]
    var onPick: (([URL]) -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $show) {
                if let handler = onPick {
                    DocumentPicker(contentTypes: types, allowsMultipleSelection: false) { urls in
                        handler(urls)
                    }
                    .ignoresSafeArea()
                } else {
                    EmptyView()
                }
            }
    }
}
private extension View {
    func fileImporterSupport(show: Binding<Bool>, types: [UTType], onPick: (([URL]) -> Void)?) -> some View {
        modifier(FileImporterSupport(show: show, types: types, onPick: onPick))
    }
}

// MARK: - Preview
struct ImportScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ImportScoreView()
    }
}
