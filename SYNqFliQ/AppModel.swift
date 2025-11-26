//
//  AppModel.swift
//  SYNqFliQ
//
//  Central app state & bundled sheet loader.
//
//  Notes:
//  - Keeps a single source of truth for currently selected sheet filename.
//  - Exposes simple helpers to open/close the song selection UI so other views (e.g. ContentView)
//    can request "戻る（選曲に戻る）" by setting `appModel.showingSongSelection = true` or by calling helpers below.
//  - Assumes `Sheet`, `SheetNote`, `Note`, and `SheetFileManager` types exist elsewhere in the project.
//

import Foundation
import Combine

// Small wrapper so we don't rely on plain tuples everywhere.
// Equatable is implemented using filename only (change if you need full-sheet equality).
struct BundledSheet: Identifiable, Equatable {
    let filename: String
    let sheet: Sheet

    var id: String { filename }

    static func == (lhs: BundledSheet, rhs: BundledSheet) -> Bool {
        return lhs.filename == rhs.filename
    }
}

final class AppModel: ObservableObject {
    @Published var showingSongSelection: Bool = false

    // Use the typed BundledSheet rather than a raw tuple
    @Published var bundledSheets: [BundledSheet] = []

    @Published var selectedSheetFilename: String? = nil
    @Published var selectedDifficulty: String? = nil
    // AppModel.swift の class AppModel: ObservableObject { ... } の中
    @Published var selectedChapter: String? = nil

    var selectedSheet: Sheet? {
        guard let fn = selectedSheetFilename else { return nil }
        return bundledSheets.first(where: { $0.filename == fn })?.sheet
    }

    init() {
        loadBundledSheets()
    }

    // Replace your existing loadBundledSheets() implementation with this function body.
    func loadBundledSheets() {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [BundledSheet] = []
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            // 1) try subdirectory "bundled-sheets"
            if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets"), !urls.isEmpty {
                for url in urls {
                    do {
                        let data = try Data(contentsOf: url)
                        let sheet = try decoder.decode(Sheet.self, from: data)
                        results.append(BundledSheet(filename: url.lastPathComponent, sheet: sheet))
                    } catch {
                        print("DBG: loadBundledSheets: failed to decode \(url.lastPathComponent): \(error)")
                    }
                }
            }

            // 2) fallback: try any json in bundle root
            if results.isEmpty {
                if let rootUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
                    for url in rootUrls {
                        guard !url.lastPathComponent.hasPrefix(".") else { continue }
                        do {
                            let data = try Data(contentsOf: url)
                            let sheet = try decoder.decode(Sheet.self, from: data)
                            if !results.contains(where: { $0.filename == url.lastPathComponent }) {
                                results.append(BundledSheet(filename: url.lastPathComponent, sheet: sheet))
                            }
                        } catch {
                            // skip non-sheet json
                        }
                    }
                }
            }

            // 3) also check Documents (imported JSON)
            do {
                let docs = try FileManager.default.contentsOfDirectory(at: SheetFileManager.documentsURL, includingPropertiesForKeys: nil, options: [])
                for url in docs where url.pathExtension.lowercased() == "json" {
                    do {
                        let data = try Data(contentsOf: url)
                        let sheet = try decoder.decode(Sheet.self, from: data)
                        if !results.contains(where: { $0.filename == url.lastPathComponent }) {
                            results.append(BundledSheet(filename: url.lastPathComponent, sheet: sheet))
                        }
                    } catch {
                        // ignore invalid json
                    }
                }
            } catch {
                // ignore
            }

            DispatchQueue.main.async {
                // preserve the current selection if it still exists in the newly loaded list.
                let previousSelection = self.selectedSheetFilename

                self.bundledSheets = results
                print("DBG: AppModel.loadBundledSheets -> found \(results.count) sheets")
                for entry in results {
                    print(" - \(entry.filename) : \(entry.sheet.title)")
                }

                // IMPORTANT: do NOT auto-set selectedSheetFilename here.
                // If there was a previous selection, keep it only if it still exists.
                if let prev = previousSelection {
                    if results.contains(where: { $0.filename == prev }) {
                        print("DBG: AppModel.loadBundledSheets preserved selectedSheetFilename = \(prev)")
                    } else {
                        // previous selection not present — do NOT overwrite it automatically.
                        // Log so we can detect unexpected states elsewhere.
                        print("DBG: AppModel.loadBundledSheets: previous selection \(prev) not present in loaded sheets; leaving selection unchanged (value may point to missing file).")
                    }
                }
            }
        }
    }

    // Selection helpers
    func selectSheet(filename: String?) {
        DispatchQueue.main.async {
            self.selectedSheetFilename = filename
        }
    }

    func selectSheet(atBundledIndex idx: Int) {
        guard bundledSheets.indices.contains(idx) else { return }
        DispatchQueue.main.async {
            self.selectedSheetFilename = self.bundledSheets[idx].filename
            self.showingSongSelection = false
        }
    }

    func clearSelection() {
        DispatchQueue.main.async {
            self.selectedSheetFilename = nil
        }
    }

    func openSongSelection() {
        DispatchQueue.main.async {
            self.showingSongSelection = true
        }
    }

    func closeSongSelection() {
        DispatchQueue.main.async {
            self.showingSongSelection = false
        }
    }
}
