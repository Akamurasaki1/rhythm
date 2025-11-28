//
//  ChapterSelectionView.swift
//  SYNqFliQ
//
//  Updated: adds a horizontal carousel-style presentation for chapters
//  keeping the original public API and helper function names (loadThumbnailImage, chapterThumbnailView, etc).
//  Tap a chapter card to center it and (after a short animation) call onSelect(chapter).
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
    // Provided data / callbacks (unchanged)
    let chapters: [Chapter]
    var onSelect: (Chapter) -> Void
    var onClose: (() -> Void)? = nil

    // environment model(s)
    @EnvironmentObject var appModel: AppModel

    // local state (preserve earlier helper names)
    @State private var searchText: String = ""
    @State private var playHistory: [PlayRecord] = []
    @State private var selectedIndex: Int = 0
    @State private var focusedIndex: Int? = nil
    @State private var showDifficulty: Bool = false
    @State private var initialScrollPerformed: Bool = false

    // carousel layout params
   // private let carouselItemWidth: CGFloat = .width * 0.8
    private let carouselItemSpacing: CGFloat = 18

    public init(chapters: [Chapter],
                onSelect: @escaping (Chapter) -> Void,
                onClose: (() -> Void)? = nil) {
        self.chapters = chapters
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
    /*    VStack(spacing: 8) {
            Text("This is ChapterSelectionView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        }*/
       // NavigationView {
        GeometryReader { geo in
            /*// 左カラム幅を固定（必要なら値を調整してください）
            let leftColWidth: CGFloat = 250
            let rightWidth = max(0, (geo.size.width - leftColWidth)*0.8)

            HStack(alignment: .top) {
                // Left: NavigationView containing only the search/toolbar (keeps sidebar look)
                NavigationView {
                    VStack(spacing: 8) {
                        // Search + toolbar area
                        VStack(spacing: 8) {
                            TextField("Search chapters", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle")
                            }
                            .opacity(searchText.isEmpty ? 0.0 : 1.0)
                        }
                        .padding()

                        Spacer() // keep search at top of left column
                    }
                    .navigationTitle("Chapters")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            if let onClose = onClose {
                                Button("Back") { onClose() }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { loadHistory() }) {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .onAppear { loadHistory() }
                }
                .frame(minWidth: leftColWidth,maxHeight: leftColWidth*0.8) // 固定幅の左カラム
*/
            let headerHeight: CGFloat = 92
                // Right: carousel area (outside the NavigationView) — pass only the right column size
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { onClose?() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Text("Chapters")
                            .font(.title2).bold()
                        
                        Spacer()
                        
                        Button(action: { loadHistory() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        TextField("Search chapters", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle")
                        }
                        .opacity(searchText.isEmpty ? 0.0 : 1.0)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
                .frame(height: headerHeight)
                .background(Color(UIColor.systemBackground))
                .zIndex(1) // ensure header sits visually above the cards if overlapping
                VStack{
                    carouselView(size: CGSize(width: geo.size.width*0.9, height: geo.size.height))

                    
                    // focus details (optional) - keep as you had them
                    if let idx = focusedIndex, filteredChapters.indices.contains(idx) {
                        // ... your existing focusedIndex UI (unchanged) ...
                    } else {
                        Spacer().frame(height: 8)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } // HStack
        } // GeometryReader
        
     }

    // MARK: - Carousel (fixed for rotation / landscape centering)
    @ViewBuilder

    private func carouselView(size: CGSize) -> some View {
        Spacer().frame(height: 2)

        if filteredChapters.isEmpty {
            VStack {
                Spacer()
                Text("No chapters available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(UIColor.secondarySystemFill))
                    .cornerRadius(10)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id("empty_placeholder")
        } else {
            let entriesCount = filteredChapters.count
            let initialIndex = max(0, entriesCount / 2)

            ScrollViewReader { proxy in
                // give the scroll/stack a named coordinate space so item frames are measured relative to it
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: carouselItemSpacing) {
                        ForEach(filteredChapters.indices, id: \.self) { i in
                            GeometryReader { itemGeo in
                                // measure frame in our named coordinate space
                                let frame = itemGeo.frame(in: .global)
                                let centerX = size.width / 2.0
                                let midX = frame.midX
                                let diff = midX - centerX
                                let normalized = max(-1.0, min(1.0, diff / (size.width * 0.5)))
                                let rotateDeg = -normalized * 20.0
                                let scale = 1.0 - abs(normalized) * 0.25
                                let opacity = 1.0 - abs(normalized) * 0.5
                                let ch = filteredChapters[i]
                                let overall = overallCountsForChapter(ch.id)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(UIColor.systemBackground))
                                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 4)

                                    HStack {
                                        chapterThumbnailView(ch)
                                            .frame(width: 96, height: 96)
                                            .cornerRadius(10)
                                            .clipped()
                                            .padding(.leading, 12)

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(ch.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.8)
                                            if let st = ch.subtitle {
                                                Text(st)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            // NEW: difficulty chips inside card (show played/total as text)
                                                        let diffs = difficultiesForChapter(ch.id)
                                                        if !diffs.isEmpty {
                                                            ScrollView(.horizontal, showsIndicators: false) {
                                                                HStack(spacing: 8) {
                                                                    ForEach(diffs, id: \.self) { diff in
                                                                        let c = countsFor(chapterId: ch.id, difficulty: diff)
                                                                        HStack(spacing: 6) {
                                                                            Text(diff)
                                                                                .font(.caption2).bold()
                                                                            Text("\(c.played)/\(c.total)")
                                                                                .font(.caption2)
                                                                                .foregroundColor(.secondary)
                                                                        }
                                                                        .padding(.horizontal, 10)
                                                                        .padding(.vertical, 6)
                                                                        .background(Color(UIColor.secondarySystemFill))
                                                                        .cornerRadius(8)
                                                                    }
                                                                }
                                                            }
                                                          //  .frame(height: 34)
                                                        }

                                            Spacer()
                                            HStack {
                                                Text("\(overall.played)/\(overall.total) played")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                            }
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.trailing, 16)
                                    }
                                }
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .rotation3DEffect(.degrees(rotateDeg), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        selectedIndex = i
                                        focusedIndex = i
                                        showDifficulty = true
                                        proxy.scrollTo(i, anchor: .center)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                        if filteredChapters.indices.contains(i) {
                                            onSelect(filteredChapters[i])
                                        }
                                    }
                                }
                            }
                            .frame(width: size.width*0.8, height: 140)
                            .id(i)
                        }
                    }
                    .padding(.vertical, 12)
                    // compute horizontal padding so first/last items are centered;
                    // clamp to >= 0 to avoid negative padding in very wide layouts
                    .padding(.horizontal, max(0, (size.width - size.width * 0.8) / 2 - carouselItemSpacing))
                    .coordinateSpace(name: "carouselSpace")
                }
                .onAppear {
                    if !initialScrollPerformed {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            proxy.scrollTo(initialIndex, anchor: .center)
                            initialScrollPerformed = true
                            focusedIndex = initialIndex
                        }
                    }
                }
            }
        }
    }

    // MARK: - Thumbnail helper (keeps original function name)
    private func loadThumbnailImage(named imageFilename: String) -> URL? {
        guard !imageFilename.isEmpty else { return nil }
        let ext = (imageFilename as NSString).pathExtension
        let name = (imageFilename as NSString).deletingPathExtension

        // 1) Documents
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docCandidate = docs.appendingPathComponent(imageFilename)
            if fm.fileExists(atPath: docCandidate.path) { return docCandidate }
            let docCandidateNoExt = docs.appendingPathComponent(name)
            if fm.fileExists(atPath: docCandidateNoExt.path) { return docCandidateNoExt }
        }

        // 2) bundle subdirectory "bundled-resources"
        if let url = Bundle.main.url(forResource: imageFilename, withExtension: nil, subdirectory: "bundled-resources") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext, subdirectory: "bundled-resources") {
            return url
        }

        // 3) bundle root
        if let url = Bundle.main.url(forResource: imageFilename, withExtension: nil) { return url }
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext) { return url }

        return nil
    }

    @ViewBuilder
    private func chapterThumbnailView(_ ch: Chapter) -> some View {
        if let fname = ch.thumbnailFilename {
            if let url = loadThumbnailImage(named: fname),
               let data = try? Data(contentsOf: url),
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                let nameNoExt = (fname as NSString).deletingPathExtension
                if let ui = UIImage(named: nameNoExt) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.secondarySystemFill))
                        Image(systemName: "book.fill").foregroundColor(.white.opacity(0.7)).font(.title2)
                    }
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.secondarySystemFill))
                Image(systemName: "book.fill").foregroundColor(.white.opacity(0.7)).font(.title2)
            }
        }
    }

    // MARK: - Filtering (keeps original name)
    private var filteredChapters: [Chapter] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return chapters }
        let q = searchText.lowercased()
        return chapters.filter {
            $0.title.lowercased().contains(q) ||
            ($0.subtitle?.lowercased().contains(q) ?? false) ||
            $0.id.lowercased().contains(q)
        }
    }

    // MARK: - Count helpers (unchanged names / behavior)
    private func countsFor(chapterId: String, difficulty: String) -> (played: Int, total: Int) {
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
        let preferredOrder = ["Base", "Flow", "Core", "Limit", "Infinity"]
        var ordered: [String] = []
        for p in preferredOrder where diffs.contains(p) { ordered.append(p) }
        for d in diffs where !ordered.contains(d) { ordered.append(d) }
        return ordered
    }

    // MARK: - History load (keeps original name)
    private func loadHistory() {
        playHistory = PlayHistoryStorage.load()
    }
}
