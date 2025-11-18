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
    @Published var bundledSheets: [(filename: String, sheet: Sheet)] = []
    
    init() {
        loadBundledSheets()
    }
    
    func loadBundledSheets() {
        var results: [(String, Sheet)] = []
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        // 1) Try the simple subdirectory lookup first (works if you added a folder reference or real subdirectory)
        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets"), !urls.isEmpty {
            print("DBG: found \(urls.count) json(s) in bundled-sheets subdirectory")
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let sheet = try decoder.decode(Sheet.self, from: data)
                    results.append((url.lastPathComponent, sheet))
                } catch {
                    print("DBG: loadBundledSheets: failed to decode \(url.lastPathComponent): \(error)")
                }
            }
        } else {
            // 2) Fallback: enumerate all json in bundle root (or any bundle location) and pick those whose path contains "bundled-sheets"
            if let allUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil), !allUrls.isEmpty {
                let filtered = allUrls.filter { $0.path.lowercased().contains("bundled-sheets") }
                if !filtered.isEmpty {
                    print("DBG: found \(filtered.count) json(s) by scanning bundle paths containing 'bundled-sheets'")
                    for url in filtered {
                        do {
                            let data = try Data(contentsOf: url)
                            let sheet = try decoder.decode(Sheet.self, from: data)
                            results.append((url.lastPathComponent, sheet))
                        } catch {
                            print("DBG: loadBundledSheets: failed to decode \(url.lastPathComponent): \(error)")
                        }
                    }
                } else {
                    // 3) Last resort: try to locate known filenames (e.g. Lyrith.json) or use any json that looks like a Sheet
                    print("DBG: no 'bundled-sheets' subdir detected; scanning all bundle json for sheet-like files (last-resort)")
                    var successful = 0
                    for url in allUrls {
                        do {
                            let data = try Data(contentsOf: url)
                            // Attempt decode; if it decodes to Sheet, accept it.
                            let sheet = try decoder.decode(Sheet.self, from: data)
                            results.append((url.lastPathComponent, sheet))
                            successful += 1
                        } catch {
                            // skip
                        }
                    }
                    print("DBG: scanned all bundle json, decoded \(successful) as Sheet")
                }
            } else {
                print("DBG: Bundle contains no json resources at all")
            }
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
