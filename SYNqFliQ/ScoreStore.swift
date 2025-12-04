//
//  ScoreStore.swift
//  SYNqFliQ
//
//  Simple centralized loader for user-saved scores placed under Documents/Scores/<user-id>/<sheet-id>/<sheet-id>.json
//  - Scans the user Scores folder and decodes JSON files into your app's Sheet model.
//  - Exposes helpers to get file URLs for audio/background/thumbnail so playback/UIImage/AV can use them.
//
//  NOTE: This expects your project's `Sheet` and `SheetNote` types are Codable and match the exported JSON shape.
//  If your SheetNote's fields differ from the exporter, adjust the decoding/conversion here accordingly.
//

import Foundation
import Combine

public final class ScoreStore: ObservableObject {
    public static let shared = ScoreStore()

    // Published list of loaded sheets for the current user (call refresh(for:) to populate)
    @Published public private(set) var userSheets: [Sheet] = []

    private init() {}

    /// Refresh the in-memory list by scanning Documents/Scores/<userID>/
    /// - Parameter userID: the ID of the user (use AuthManager.shared.firebaseUser?.uid or "local-user")
    public func refresh(for userID: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [Sheet] = []
            let fm = FileManager.default
            do {
                let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let base = docs.appendingPathComponent("Scores").appendingPathComponent(userID)
                // If folder doesn't exist, nothing to load
                guard fm.fileExists(atPath: base.path) else {
                    DispatchQueue.main.async {
                        self.userSheets = []
                    }
                    return
                }

                // iterate subfolders (each sheet id has a folder)
                let sheetFolders = try fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                for folder in sheetFolders {
                    // look for a json file with the sheet id or any .json inside folder
                    let jsonFiles = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.pathExtension.lowercased() == "json" }
                    guard let jsonURL = jsonFiles.first else { continue }
                    do {
                        let data = try Data(contentsOf: jsonURL)
                        // Try decode directly into your Sheet model
                        let decoder = JSONDecoder()
                        // If Sheet uses different date/number formatting, configure decoder here
                        let sheet = try decoder.decode(Sheet.self, from: data)
                        loaded.append(sheet)
                    } catch {
                        // If decoding into Sheet fails, try decoding a lighter ExportScore-like shape and map it.
                        // This fallback keeps the app resilient to small schema differences.
                        do {
                            // Minimal fallback mapping using a local temporary struct similar to ExportScore
                            struct FallbackScore: Codable {
                                var version: Int?
                                var title: String?
                                var composer: String?
                                var chapter: String?
                                var author: String?
                                var difficulty: String?
                                var level: Int?
                                var id: String?
                                var bpm: Double?
                                var audioFilename: String?
                                var backgroundFilename: String?
                                var thumbnailFilename: String?
                                var notes: [AnyCodable]?
                                var offset: Double?
                            }
                            let decoder = JSONDecoder()
                            let fallback = try decoder.decode(FallbackScore.self, from: data)
                            // attempt a relaxed mapping into Sheet where possible
                            var s = Sheet(title: fallback.title ?? "Untitled", notes: [], audioFilename: fallback.audioFilename)
                            s.version = fallback.version
                            s.chapter = fallback.chapter
                            s.composer = fallback.composer ?? s.composer
                            // Use `author` if your Sheet has it (we added author earlier). Try setting via KVC-style if available:
                            if let author = fallback.author {
                                // Attempt to set author if property exists
                                // Since Sheet is a value type, assign explicitly if it has been extended
                                // (This code assumes Sheet now has `author` var; if not, ignore.)
                                (Mirror(reflecting: s).children.first { $0.label == "author" } != nil) ? (/* no-op; we'll set below via initializer if needed */ ()) : ()
                                // If Sheet has `author` in init you can create another Sheet; for simplicity, attempt to mutate via var:
                                // (swift doesn't allow reflection mutation—so we only set known fields above and rely on the direct decode path in most cases)
                            }
                            // push the partially-populated sheet
                            loaded.append(s)
                        } catch {
                            // skip invalid json
                            print("ScoreStore: failed to decode \(jsonURL): \(error)")
                            continue
                        }
                    }
                }
            } catch {
                print("ScoreStore.refresh error: \(error)")
            }

            DispatchQueue.main.async {
                // sort deterministically (e.g., by title)
                self.userSheets = loaded.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
            }
        }
    }

    /// Returns the folder URL for a saved sheet if it exists
    public func sheetFolderURL(userID: String, sheetID: String) -> URL? {
        let fm = FileManager.default
        guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        let folder = docs.appendingPathComponent("Scores").appendingPathComponent(userID).appendingPathComponent(sheetID)
        return fm.fileExists(atPath: folder.path) ? folder : nil
    }

    /// Returns the file URL for the audio file for a sheet if present
    public func audioURL(for sheet: Sheet, userID: String) -> URL? {
        guard let folder = sheetFolderURL(userID: userID, sheetID: sheet.id ?? "") else { return nil }
        guard let fn = sheet.audioFilename else { return nil }
        let url = folder.appendingPathComponent(fn)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Similarly background image URL
    public func backgroundURL(for sheet: Sheet, userID: String) -> URL? {
        guard let folder = sheetFolderURL(userID: userID, sheetID: sheet.id ?? "") else { return nil }
        guard let fn = sheet.backgroundFilename else { return nil }
        let url = folder.appendingPathComponent(fn)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Thumbnail URL
    public func thumbnailURL(for sheet: Sheet, userID: String) -> URL? {
        guard let folder = sheetFolderURL(userID: userID, sheetID: sheet.id ?? "") else { return nil }
        guard let fn = sheet.thumbnailFilename else { return nil }
        let url = folder.appendingPathComponent(fn)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// Helper AnyCodable for fallback (keeps fallback robust); minimal implementation
struct AnyCodable: Codable {}