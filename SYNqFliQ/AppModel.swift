//
//  AppModel.swift
//  SYNqFliQ
//
//  Robust bundled-sheets loader: tries subdirectory, falls back to scanning bundle.
//  Detects files like Resources/bundled-sheets/Lyrith.json even if project uses groups.
//

import Foundation
import Combine

final class AppModel: ObservableObject {
    // array of (filename, sheet)
    @Published var bundledSheets: [(filename: String, sheet: Sheet)] = []

    // Currently selected sheet identifier (filename as stored in bundledSheets)
    @Published var selectedSheetFilename: String? = nil
    @Published var selectedDifficulty: String? = nil

    init() {
        loadBundledSheets()
    }

    // computed convenience to get the selected Sheet if any
    var selectedSheet: Sheet? {
        guard let fn = selectedSheetFilename else { return nil }
        return bundledSheets.first(where: { $0.filename == fn })?.sheet
    }

    func loadBundledSheets() {
        var results: [(String, Sheet)] = []
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets"), !urls.isEmpty {
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let sheet = try decoder.decode(Sheet.self, from: data)
                    results.append((url.lastPathComponent, sheet))
                } catch {
                    print("DBG: loadBundledSheets: failed to decode \(url.lastPathComponent): \(error)")
                }
            }
        } else if let allUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil), !allUrls.isEmpty {
            // fallback scanning
            var successful = 0
            for url in allUrls {
                do {
                    let data = try Data(contentsOf: url)
                    let sheet = try decoder.decode(Sheet.self, from: data)
                    results.append((url.lastPathComponent, sheet))
                    successful += 1
                } catch {
                    // skip non-sheet json
                }
            }
            print("DBG: scanned all bundle json, decoded \(successful) as Sheet")
        } else {
            print("DBG: Bundle contains no json resources at all")
        }

        DispatchQueue.main.async {
            self.bundledSheets = results
            print("DBG: AppModel.bundledSheets has \(self.bundledSheets.count) entries:")
            for (fn, s) in self.bundledSheets {
                print("  - \(fn) : \(s.title)")
            }
        }
    }
}
