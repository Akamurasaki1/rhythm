// Complete, deduplicated implementation of ScoreStore.
// Replaces previous partial/duplicated definitions and provides a single source of truth.
// - Singleton ScoreStore.shared
// - @Published userSheets: [Sheet]
// - refresh(for:) which scans Documents/Scores/<userID>/ and loads sheets
// - loadUserSheets(for:) helper used by refresh(for:)
// - helpers to locate sheet folder and asset URLs (audio/background/thumbnail)
// - lightweight fallback decoding path for older/partial JSON shapes
//
// NOTE: This file depends on your project's `Sheet` model type being Codable and having at least
//       the properties referenced below (title, notes, audioFilename, backgroundFilename, thumbnailFilename, id, difficulty, composer, chapter, bpm, level, author).
//       If your Sheet shape differs, adjust mapping in the fallback decode branch accordingly.

import Foundation
import Combine

public final class ScoreStore: ObservableObject {
    public static let shared = ScoreStore()

    // Published list of loaded sheets for the current user (call refresh(for:) to populate)
    @Published public private(set) var userSheets: [Sheet] = []

    private init() {}

    /// Refresh the in-memory list by scanning Documents/Scores/<userID>/
    /// This spawns a background task and updates `userSheets` on the main queue.
    public func refresh(for userID: String) {
        // perform scanning on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.loadUserSheets(for: userID)
        }
    }

    /// Scans Documents/Scores/<userID>/ and attempts to decode sheet JSON files into Sheet values.
    /// On success, assigns sorted results to the published `userSheets`.
    func loadUserSheets(for userID: String) {
        var loaded: [Sheet] = []
        let fm = FileManager.default
        do {
            let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let base = docs.appendingPathComponent("Scores").appendingPathComponent(userID)
            // If folder does not exist, clear userSheets and return
            guard fm.fileExists(atPath: base.path) else {
                DispatchQueue.main.async {
                    self.userSheets = []
                    print("ScoreStore: no Scores folder for user=\(userID)")
                }
                return
            }

            // iterate subdirectories (each sheet is expected to live in its own folder)
            let folderContents = try fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)

            for candidate in folderContents {
                // only consider directories
                var isDir: ObjCBool = false
                if !fm.fileExists(atPath: candidate.path, isDirectory: &isDir) || !isDir.boolValue { continue }

                // find the first .json file inside the directory (convention: <safeID>.json)
                let filesInDir = try fm.contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                guard let jsonURL = filesInDir.first(where: { $0.pathExtension.lowercased() == "json" }) else { continue }

                do {
                    let data = try Data(contentsOf: jsonURL)
                    let decoder = JSONDecoder()
                    // Prefer strict decode into Sheet
                    var sheet = try decoder.decode(Sheet.self, from: data)
                    // Ensure id is present: prefer json id, fallback to folder name
                    if sheet.id == nil || sheet.id?.isEmpty == true {
                        sheet.id = candidate.lastPathComponent
                    }
                    loaded.append(sheet)
                } catch {
                    // Fallback decode path: attempt to decode a relaxed struct and map into Sheet minimally
                    // This keeps backward compatibility with older import formats.
                    do {
                        let data = try Data(contentsOf: jsonURL)
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
                        }
                        let decoder = JSONDecoder()
                        let fallback = try decoder.decode(FallbackScore.self, from: data)

                        // Construct a minimal Sheet. This assumes Sheet has an initializer like:
                        // Sheet(title: String, notes: [SheetNote], audioFilename: String?)
                        // and mutable properties for the rest. Adjust if your Sheet type differs.
                        var s = Sheet(title: fallback.title ?? "Untitled", notes: [], audioFilename: fallback.audioFilename)
                        s.version = fallback.version
                        s.chapter = fallback.chapter
                        s.composer = fallback.composer ?? s.composer
                        s.author = fallback.author ?? (s.author ?? nil)
                        s.difficulty = fallback.difficulty
                        s.level = fallback.level
                        s.id = (fallback.id?.isEmpty == false) ? fallback.id : candidate.lastPathComponent
                        s.bpm = fallback.bpm ?? s.bpm
                        s.backgroundFilename = fallback.backgroundFilename
                        s.thumbnailFilename = fallback.thumbnailFilename

                        loaded.append(s)
                    } catch {
                        print("ScoreStore: failed to decode \(jsonURL): \(error)")
                        continue
                    }
                }
            }
        } catch {
            print("ScoreStore.refresh error scanning folders: \(error)")
        }

        // Sort deterministically and publish on main thread
        DispatchQueue.main.async {
            self.userSheets = loaded.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
            print("ScoreStore: loaded \(self.userSheets.count) user sheets for user=\(userID)")
        }
    }

    // MARK: - Helpers to locate sheet folders and assets

    /// Returns the folder URL for a saved sheet if it exists
    public func sheetFolderURL(userID: String, sheetID: String) -> URL? {
        let fm = FileManager.default
        guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        let folder = docs.appendingPathComponent("Scores").appendingPathComponent(userID).appendingPathComponent(sheetID)
        return fm.fileExists(atPath: folder.path) ? folder : nil
    }

    /// Returns the file URL for the audio file for a sheet if present
    public func audioURL(for sheet: Sheet, userID: String) -> URL? {
        return assetURL(for: sheet, filename: sheet.audioFilename, userID: userID)
    }

    /// Returns the file URL for the background image for a sheet if present
    public func backgroundURL(for sheet: Sheet, userID: String) -> URL? {
        return assetURL(for: sheet, filename: sheet.backgroundFilename, userID: userID)
    }

    /// Returns the file URL for the thumbnail image for a sheet if present
    public func thumbnailURL(for sheet: Sheet, userID: String) -> URL? {
        return assetURL(for: sheet, filename: sheet.thumbnailFilename, userID: userID)
    }

    /// Generic asset resolution helper: prefers Documents/Scores/<userID>/<sheet.id>/<filename>, falls back to Documents/<filename>
    private func assetURL(for sheet: Sheet, filename: String?, userID: String) -> URL? {
        guard let filename = filename, !filename.isEmpty else { return nil }
        let fm = FileManager.default

        // 1) if sheet id available, check the per-sheet folder
        if let sid = sheet.id, !sid.isEmpty,
           let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let candidate = docs.appendingPathComponent("Scores").appendingPathComponent(userID).appendingPathComponent(sid).appendingPathComponent(filename)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }

        // 2) fallback: Documents root (older imports may have put files there)
        if let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let candidate = docs.appendingPathComponent(filename)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }

        // 3) not found
        return nil
    }
}

/// Minimal AnyCodable used for fallback decoding; keeps fallback robust without pulling in external libs.
struct AnyCodable: Codable {}
