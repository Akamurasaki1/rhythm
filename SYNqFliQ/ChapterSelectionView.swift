//
//  ChapterSelectionVIew.swift
//  SYNqFliQ
//
//  Rewritten: chapter list that shows per-chapter and per-difficulty played/total counts.
//  - Tap a chapter row to call onSelect(chapter).
//  - Uses AppModel.bundledSheets and PlayHistoryStorage.load() to compute counts.
//  - Adjust property accesses if your bundled sheet / PlayRecord types use different field names.
//
import SwiftUI

public struct Chapter: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let thumbnailFilename: String?

    public init(id: String, title: String, subtitle: String? = nil, thumbnailFilename: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.thumbnailFilename = thumbnailFilename
    }
}

public struct ChapterSelectionView: View {
    // Provided data / callbacks
    let chapters: [Chapter]
    var onSelect: (Chapter) -> Void
    var onClose: (() -> Void)? = nil

    // environment model(s) — your project should provide AppModel and PlayHistoryStorage/PlayRecord
    @EnvironmentObject var appModel: AppModel

    // local state
    @State private var searchText: String = ""
    @State private var playHistory: [PlayRecord] = []

    public init(chapters: [Chapter],
                onSelect: @escaping (Chapter) -> Void,
                onClose: (() -> Void)? = nil) {
        self.chapters = chapters
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        NavigationView {
            List {
                if filteredChapters.isEmpty {
                    Text("No chapters").foregroundColor(.secondary)
                } else {
                    ForEach(filteredChapters) { ch in
                        Button(action: { onSelect(ch) }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 12) {
                                    chapterThumbnailView(ch)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(ch.title)
                                                .font(.headline)
                                            Spacer()
                                            let overall = overallCountsForChapter(ch.id)
                                            Text("\(overall.played)/\(overall.total) played")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        if let st = ch.subtitle {
                                            Text(st).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }

                                // difficulties summary (compact)
                                let diffs = difficultiesForChapter(ch.id)
                                if !diffs.isEmpty {
                                    HStack(spacing: 8) {
                                        ForEach(diffs, id: \.self) { diff in
                                            let c = countsFor(chapterId: ch.id, difficulty: diff)
                                            HStack(spacing: 6) {
                                                Text(diff)
                                                    .font(.caption2)
                                                    .bold()
                                                    .lineLimit(1)
                                                Text("\(c.played)/\(c.total)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(Color(white: 0.96))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Chapters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let onClose = onClose {
                        Button("Back") { onClose() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle")
                    }.opacity(searchText.isEmpty ? 0.0 : 1.0)
                }
            }
            .searchable(text: $searchText, prompt: "Search chapters")
            .onAppear { loadHistory() }
        }
    }

    // MARK: - Thumbnail helper
    // Helper: load UIImage from Documents (for runtime-updated images) or bundle subdirectory fallback
/*    func loadThumbnailImage(named filename: String, bundleSubdirectory: String = "bundled-chapthumbnail") -> UIImage? {
        // 1) Documents (allows runtime update)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsURL = docs.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: docsURL.path), let data = try? Data(contentsOf: docsURL), let ui = UIImage(data: data) {
                print("DBG: loaded thumbnail from Documents:", docsURL.path)
                return ui
            }
        }

        // 2) Asset catalog (name without extension)
        let nameNoExt = (filename as NSString).deletingPathExtension
        if let ui = UIImage(named: nameNoExt) {
            print("DBG: loaded thumbnail from Assets:", nameNoExt)
            return ui
        }

        // 3) Bundle subdirectory (e.g. "bundled-chapthumbnail")
        if let url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: bundleSubdirectory),
           let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
            print("DBG: loaded thumbnail from bundle subdir:", url.path)
            return ui
        }
        if let url2 = Bundle.main.url(forResource: nameNoExt, withExtension: (filename as NSString).pathExtension.isEmpty ? nil : (filename as NSString).pathExtension, subdirectory: bundleSubdirectory),
           let data = try? Data(contentsOf: url2), let ui = UIImage(data: data) {
            print("DBG: loaded thumbnail from bundle subdir (split):", url2.path)
            return ui
        }

        // 4) Bundle root
        if let path = Bundle.main.path(forResource: nameNoExt, ofType: (filename as NSString).pathExtension.isEmpty ? nil : (filename as NSString).pathExtension),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let ui = UIImage(data: data) {
            print("DBG: loaded thumbnail from bundle root:", path)
            return ui
        }

        print("DBG: thumbnail not found in any location for:", filename)
        return nil
    } */
    private func loadThumbnailImage(named imageFilename: String) -> URL? {
        guard !imageFilename.isEmpty else { return nil }
        let ext = (imageFilename as NSString).pathExtension
        let name = (imageFilename as NSString).deletingPathExtension

        // prefer bundled-resources subdirectory, fall back to top-level bundle, then Documents
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext, subdirectory: "bundled-resources") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext) {
            return url
        }
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let candidate = docs.appendingPathComponent(imageFilename)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }
    @ViewBuilder
    private func chapterThumbnailView(_ ch: Chapter) -> some View {

            if let ChapThumbImgName = ch.thumbnailFilename, let ui_url = loadThumbnailImage(named: ChapThumbImgName),let data = try? Data(contentsOf: ui_url), let uiimg = UIImage(data:data) {
            Image(uiImage: uiimg)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipped()
                .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.16))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "book.fill").foregroundColor(.white.opacity(0.7)))
        }
    }
    // MARK: - Filtering
    private var filteredChapters: [Chapter] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return chapters }
        let q = searchText.lowercased()
        return chapters.filter {
            $0.title.lowercased().contains(q) ||
            ($0.subtitle?.lowercased().contains(q) ?? false) ||
            $0.id.lowercased().contains(q)
        }
    }

    // MARK: - Count helpers
    // NOTE: These functions assume your appModel.bundledSheets elements expose:
    //   - entry.filename : String
    //   - entry.sheet.chapter : String?
    //   - entry.sheet.difficulty : String?
    // If your types differ, adjust the property accesses accordingly.

    private func countsFor(chapterId: String, difficulty: String) -> (played: Int, total: Int) {
        // filter bundled sheets for chapter + difficulty
        let entries = appModel.bundledSheets.filter { entry in
            let sheetChapter = (entry.sheet.chapter ?? "all")
            let sheetDiff = (entry.sheet.difficulty ?? "")
            return sheetChapter == chapterId && sheetDiff == difficulty
        }
        let totalSet = Set(entries.map { $0.filename })
        if totalSet.isEmpty { return (0, 0) }

        let playedSet: Set<String> = Set(playHistory.compactMap { rec in
            guard let fn = rec.sheetFilename else { return nil }
            if let recDiff = rec.difficulty {
                return recDiff == difficulty ? fn : nil
            } else {
                // if history lacks difficulty, count by filename
                return fn
            }
        })

        let playedCount = totalSet.intersection(playedSet).count
        return (playedCount, totalSet.count)
    }

    private func overallCountsForChapter(_ chapterId: String) -> (played: Int, total: Int) {
        let entries = appModel.bundledSheets.filter { entry in
            let sheetChapter = (entry.sheet.chapter ?? "all")
            return sheetChapter == chapterId
        }
        let totalSet = Set(entries.map { $0.filename })
        if totalSet.isEmpty { return (0, 0) }

        let playedSet: Set<String> = Set(playHistory.compactMap { $0.sheetFilename })
        let playedCount = totalSet.intersection(playedSet).count
        return (playedCount, totalSet.count)
    }

    private func difficultiesForChapter(_ chapterId: String) -> [String] {
        let entries = appModel.bundledSheets.filter { entry in
            (entry.sheet.chapter ?? "all") == chapterId
        }
        let diffs = Set(entries.compactMap { entry in entry.sheet.difficulty })
        // prefer a human-friendly order if present
        let preferredOrder = ["Beginner", "Easy", "Normal", "Hard", "Core", "Limit"]
        var ordered: [String] = []
        for p in preferredOrder where diffs.contains(p) { ordered.append(p) }
        for d in diffs where !ordered.contains(d) { ordered.append(d) }
        return ordered
    }

    // MARK: - History load
    private func loadHistory() {
        // Expect PlayHistoryStorage.load() -> [PlayRecord]
        playHistory = PlayHistoryStorage.load()
    }
}
