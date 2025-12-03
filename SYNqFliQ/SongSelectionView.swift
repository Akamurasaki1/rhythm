//
//  SongSelectionView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//  Revised by assistant: unified difficulty-selection flow and ensured difficulty buttons pick correct file
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit
import AVKit

// Lightweight example cell using closure style (kept for reference / reuse)
struct SongCell_ClosureExample: View {
    let song: SongSelectionView.SongSummary
    @State private var chosenDifficulty: String? = nil
    @EnvironmentObject private var appModel: AppModel
    var onChoose: ((SongSelectionView.SongSummary, String?) -> Void)? = nil

    var body: some View {
        Button(action: {
            // Persist selection into the shared model
            appModel.selectedSheetFilename = song.id
            appModel.selectedDifficulty = chosenDifficulty

            print("DBG: SongCell (closure) tapped -> set appModel.selectedSheetFilename = \(String(describing: appModel.selectedSheetFilename))")

            // Notify caller
            onChoose?(song, chosenDifficulty)

            // Close selection UI
            appModel.closeSongSelection()
        }) {
            HStack {
                Text(song.title)
                
                Spacer()
                if let idx = song.bundledIndex, appModel.bundledSheets.indices.contains(idx) {
                    if let diff = appModel.bundledSheets[idx].sheet.difficulty {
                        Text(diff).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct SongSelectionView: View {
    // Public API: provide list of songs to show and callbacks
    struct SongSummary: Identifiable, Equatable {
        let id: String        // e.g. sheet.filename
        let title: String
        let composer: String
        let thumbnailFilename: String? // optional image name in bundle / Documents
        let bundledIndex: Int? // optional source index
    }

    var songs: [SongSummary] = []
    var onClose: () -> Void = { }
    // onChoose passes selected SongSummary and an optional difficulty string (nil => default/unknown)
    var onChoose: (SongSummary, String?) -> Void = { _, _ in }

    init(songs: [SongSummary] = [],
         onClose: @escaping () -> Void = {},
         onChoose: @escaping (SongSummary, String?) -> Void = { _, _ in }) {
        self.songs = songs
        self.onClose = onClose
        self.onChoose = onChoose
    }

    var body: some View {
     /*   VStack(spacing: 8) {
            Text("This is SongSelectionView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        }  */
        SongSelectView(songs: songs, onChoose: onChoose, onCancel: onClose)
    }

    // MARK: - Inner View
    struct SongSelectView: View {
        var songs: [SongSummary]
        var onChoose: (SongSummary, String?) -> Void
        var onCancel: () -> Void

        // UI state
        @State private var focusedIndex: Int? = nil
        @State private var showDifficulty: Bool = false
        @State private var dragOffsetY: CGFloat = 0.0
        @GestureState private var isDetectingLongPress = false

        // carousel internal
        @State private var initialScrollPerformed: Bool = false
        @State private var selectedIndex: Int = 0
        @State private var searchText: String = "" // 検索
        private var filteredSongs: [BundledSheet] {
            let qRaw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !qRaw.isEmpty else { return appModel.bundledSheets }

            let q = qRaw.lowercased()

            return appModel.bundledSheets.filter { entry in
                // adjust property names if your model differs:
                let title = (entry.sheet.title).lowercased()
              //  let artist = (entry.sheet.artist ?? "").lowercased()
          //      let filename = entry.filename.lowercased()
              //  let chapter = (entry.sheet.chapter).lowercased()
             //   let difficulty = (entry.sheet.difficulty).lowercased()

                // match by song title, artist, filename, chapter, difficulty
                if title.contains(q) { return true }
          //      if artist.contains(q) { return true }
          //      if filename.contains(q) { return true }
          //      if chapter.contains(q) { return true }
          //      if difficulty.contains(q) { return true }

                // Optionally: match by words inside title (split) for partial multi-word queries
       //         let tokens = q.split(separator: " ").map { String($0) }
       //         if !tokens.isEmpty {
                    // require that all tokens appear somewhere (AND semantics)
                //    let hay = (title + " " + artist + " " + filename)
               //     if tokens.allSatisfy({ hay.contains($0) }) { return true }
       //         }

                return false
            }
        }
        // Paste these inside SongSelectView (struct SongSelectView: View { ... })
        // 1) filtered / visible mapping: searchText -> visible SongSummary array
        private var visibleSongs: [SongSummary] {
            let qRaw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !qRaw.isEmpty else { return songs }

            let q = qRaw.lowercased()
            var results: [SongSummary] = []
            for (idx, entry) in appModel.bundledSheets.enumerated() {
                let title = (entry.sheet.title).lowercased()
                // you can extend matching to artist/filename/etc if desired
                if title.contains(q) {
                    results.append(SongSummary(
                        id: entry.filename,
                        title: entry.sheet.title,
                        composer: entry.sheet.composer,
                        thumbnailFilename: entry.sheet.thumbnailFilename,
                        bundledIndex: idx
                    ))
                }
            }
            return results
        }

        // 2) Reset selection state when search text changes so indices align with visibleSongs
        // Add this below your @State declarations (you may already have them) — this uses .onChange in the view body.
        // difficulty picker state (confirmationDialog)
        @EnvironmentObject private var appModel: AppModel
        @State private var showingDifficultyPicker: Bool = false
        @State private var difficultyCandidates: [BundledSheet] = []
        @State private var pendingSongTitle: String = ""

        // appearance
        private let carouselItemWidth: CGFloat = 100
        private let carouselItemSpacing: CGFloat = 12
        // 動的にタイルサイズを計算するヘルパー（SongSelectView の中に追加）
        private func tileSize(for containerWidth: CGFloat) -> CGSize {
            // 目的: ジャケットは正方形を想定。containerWidth に対する割合で決めつつ
            // 最小・最大を clamp して極端な端末でも崩れないようにする。
            // 調整例: 画面幅の 36% を基本に、最小 220pt、最大 500pt に制限。
            let side = min(480, max(220, containerWidth * 0.33))
            return CGSize(width: side, height: side)
        }// ジャケットのサイズ
        private let spacing: CGFloat = 18.0

        var body: some View {
            GeometryReader { geo in
                ZStack {
            // ensure header sits visually above the cards if overlapping
                    // Background: prefer asset named "selection_bg" (no extension).
                    // If the asset is missing, fall back to solid black.
                    Group {
                        if UIImage(named: "selection_bg") != nil {
                            Image("selection_bg")
                                .resizable(capInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // 全体に表示？
                                .scaledToFill()
                                .frame(maxWidth:geo.size.width,maxHeight: .infinity) // 横幅に合わせることで、縦長画面でも変にならない
                                .ignoresSafeArea()

                        } else {
                            Color.black
                        }
                    }
                    .ignoresSafeArea()

                    // Dim overlay to keep UI readable on top of bright images
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        Text("Select Song")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        Spacer().frame(alignment:.top) // 円柱風リストの上側のスペース
                        ZStack {
                            carouselView(size: geo.size)
                                .frame(height: 220)
                                .clipped()
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 6, coordinateSpace: .local)
                                .onChanged { value in
                                    if focusedIndex != nil {
                                        dragOffsetY = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if focusedIndex != nil {
                                        if value.translation.height > 120 || value.predictedEndTranslation.height > 150 {
                                            withAnimation(.easeOut) {
                                                closeFocus()
                                                onCancelIfNeeded()
                                            }
                                        } else {
                                            withAnimation(.spring()) {
                                                dragOffsetY = 0
                                              //  dragOffsetX = 0
                                            }
                                        }
                                    }
                                }
                        )

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(1)

                    // (the rest of overlays like focused tile, controls, etc. remain as before)
                
            
                    if let fi = focusedIndex, visibleSongs.indices.contains(fi) {
                        let song = visibleSongs[fi]
                        VStack(spacing: 16) {
                            let verticalShift: CGFloat = -min(geo.size.height * 0.06, 48) // move up by 6% of height, max 48pt
                            tileView(for: song)
                                .frame(width: tileSize(for:geo.size.width).width*1.12, height: tileSize(for:geo.size.width).height*1.12)
                                .shadow(radius: 12)
                                .offset(y: min(dragOffsetY, 200)+verticalShift)
                                .transition(.move(edge: .bottom).combined(with: .scale))
                                .zIndex(10)
// Base → Flow → Core → Limit → Infinity → Void（隠し1） → Null（隠し2）
                            if showDifficulty {
                                
                                HStack(spacing: 18) {
                                    let verticalShift: CGFloat = -min(geo.size.height * 0.06, 48) // move up by 6% of height, max 48pt
                                    // use the new difficultyButton that includes level if available
                                    difficultyButton("Base", for: song) { choose(song: song, difficulty: "Base") }
                                    difficultyButton("Flow", for: song) { choose(song: song, difficulty: "Flow") }
                                    difficultyButton("Core", for: song) { choose(song: song, difficulty: "Core") }
                                    difficultyButton("Limit", for: song) { choose(song: song, difficulty: "Limit") }
                                    difficultyButton("Infinity", for: song) { choose(song: song, difficulty: "Infinity") }
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .offset(y: min(dragOffsetY, 200)+verticalShift)
                                .zIndex(9)
                            } else {
                                Text("Swipe down to go back")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 6)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showDifficulty.toggle()
                            }
                        }
                        .zIndex(8)
                        .transition(.opacity)
                    }

                    VStack {
                        HStack {
                            Button(action: {
                                if focusedIndex != nil {
                                    withAnimation(.easeOut) { closeFocus() }
                                } else {
                                    onCancel()
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(8)
                            }
                            Spacer()
                            HStack {
                                TextField("Search songs", text: $searchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())

                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle")
                                }
                                .opacity(searchText.isEmpty ? 0.5 :1.0)
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal)
                            .padding(3)
                            .opacity(0.5.advanced(by: 0.1))
                            .border(Color.black.opacity(1.0), width: 1)
                            .cornerRadius(8)
                            
                        }
                        .padding()
                        Spacer()
                    }
                    .zIndex(20)
                }
                // Difficulty confirmation dialog using the difficultyCandidates prepared earlier
                .confirmationDialog("Select difficulty for \"\(pendingSongTitle)\"", isPresented: $showingDifficultyPicker, titleVisibility: .visible) {
                    ForEach(difficultyCandidates.indices, id: \.self) { i in
                        let entry = difficultyCandidates[i]
                        let label = entry.sheet.difficulty ?? "Default"
                        Button(label) {
                            performSelect(entry: entry, forSongTitle: pendingSongTitle)
                        }
                    }
                    Button("Cancel", role: .cancel) { /* nothing */ }
                }
            }
        }

        // MARK: - Carousel
        @ViewBuilder
        private func carouselView(size: CGSize) -> some View {
            Spacer().frame(alignment:.top)
            if songs.isEmpty {
                VStack {
                    Spacer()
                    Text("No songs available")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("empty_placeholder")
            } else {
                let entriesCount = visibleSongs.count
                let initialIndex = max(0, entriesCount / 2)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: carouselItemSpacing) {
                            ForEach(visibleSongs.indices, id: \.self) { i in
                                GeometryReader { itemGeo in
                                    let frame = itemGeo.frame(in: .global)
                                    let centerX = UIScreen.main.bounds.width / 2
                                    let midX = frame.midX
                                    let diff = midX - centerX
                                    let normalized = max(-1.0, min(1.0, diff / (size.width * 0.5)))
                                    let rotateDeg = -normalized * 30.0
                                    let scale = 1.0 - abs(normalized) * 0.25
                                    let opacity = 1.0 - abs(normalized) * 0.6
                                    let song = visibleSongs[i]

                                    VStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: selectedIndex == i ? 10 : 1)
                                                .fill(selectedIndex == i ? Color.black.opacity(0.9) : Color.gray.opacity(0.3))
                                                .frame(width: selectedIndex == i ? carouselItemWidth * 1.5 : carouselItemWidth , height: selectedIndex == i ? 96 : 64)
                                                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                                                
                                                
                                            VStack(spacing: 4){
                                                Text(song.title)
                                                    .foregroundColor(.white)
                                                    .bold()
                                                Text(song.composer)
                                                    .foregroundColor(Color.gray.opacity(0.9))
                                                    .bold()
                                            }
                                        
                                        }
                                        .zIndex(selectedIndex == i ? 0 : -1)
                                        .offset(x: selectedIndex == i ? carouselItemWidth * -0.25 : 0,y:selectedIndex == i ? 0 : 16)
                                    }
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .rotation3DEffect(.degrees(rotateDeg), axis: (x: 0, y: 1.2, z: 0), perspective: 0.7)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedIndex = i
                                            focusedIndex = i
                                            showDifficulty = true
                                            proxy.scrollTo(i, anchor: .center)
                                        }
                                    }
                                }
                                .frame(width: carouselItemWidth, height: 100) // タイトルと作曲者名のはいっているcarouselが見える高さと幅
                                .id(i)
                            }
                        }
                        .padding(.horizontal, (UIScreen.main.bounds.width - carouselItemWidth) / 2 - carouselItemSpacing)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        if !initialScrollPerformed {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                proxy.scrollTo(initialIndex, anchor: .center)
                                initialScrollPerformed = true
                            }
                        }
                    }
                }
            }
        }

        // MARK: - tile view
        @ViewBuilder
        private func tileView(for song: SongSummary) -> some View {
            ZStack {
                if let imgName = song.thumbnailFilename, let uiurl = bundleImageURL(named: imgName), let data = try? Data(contentsOf: uiurl), let uiimg = UIImage(data: data) {
                    Image(uiImage: uiimg)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                        .frame(alignment:.center)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                

                VStack {
                    Spacer()
                    Text(song.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.45))
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }
            }
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        

        // MARK: - difficulty button
        @ViewBuilder
        private func difficultyButton(_ text: String, for song: SongSummary, action: @escaping ()->Void) -> some View {
            // Compose label including level if available
            let levelStr = levelText(for: song, difficulty: text)
            let label = levelStr.map { "\(text)\n\($0)" } ?? text
            Button(action: action) {
                Text(label)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            }
        }

        // helper: attempt to find a level string for the given song/difficulty
        private func levelText(for song: SongSummary, difficulty: String) -> String? {
            // find the bundled entry matching this title/difficulty
            guard let entry = findEntry(for: song, matchingDifficulty: difficulty) else { return nil }

            // try common property names via Mirror to be resilient to sheet model shape
            let m = Mirror(reflecting: entry.sheet)
            for child in m.children {
                if let label = child.label?.lowercased() {
                    if label.contains("level"){
                        // prefer Int -> "Lv N"
                        if let n = child.value as? Int {
                            return "Lv.\(n)"
                        }
                        if let s = child.value as? String {
                            // if it's already like "12" or "A", return as-is or prefix with Lv if numeric
                            if let asInt = Int(s) {
                                return "Lv.\(asInt)"
                            }
                            return s
                        }
                    }
                }
            }
            // fallback: sometimes sheet may expose level as a nested metadata dict
            if let metaMirrorChildren = Mirror(reflecting: entry.sheet).children.compactMap({ $0 }) as? [Mirror.Child] {
                // no-op placeholder, primarily kept to indicate other heuristics could be added
                _ = metaMirrorChildren
            }
            return nil
        }

        // MARK: - selection helpers
        private func choose(song: SongSummary, difficulty: String) {
            // Attempt to find a BundledSheet for this title+difficulty
            if let entry = findEntry(for: song, matchingDifficulty: difficulty) {
                performSelect(entry: entry, forSongTitle: song.title)
                return
            }

            // fallback: if the provided bundledIndex points to an entry, use it
            if let idx = song.bundledIndex, appModel.bundledSheets.indices.contains(idx) {
                performSelect(entry: appModel.bundledSheets[idx], forSongTitle: song.title)
                return
            }

            // fallback: if no match, notify caller with difficulty but without filename
            print("DBG: choose: no matching entry for title=\(song.title) difficulty=\(difficulty)")
            onChoose(song, difficulty)
            appModel.closeSongSelection()
        }

        private func performSelect(entry: BundledSheet, forSongTitle title: String) {
            // persist selection into model
            appModel.selectedSheetFilename = entry.filename
            appModel.selectedDifficulty = entry.sheet.difficulty
            print("DBG: SongSelection selected -> filename=\(entry.filename) difficulty=\(String(describing: entry.sheet.difficulty))")

            // notify caller and close
            onChoose(SongSummary(id: entry.filename, title: entry.sheet.title, composer: entry.sheet.composer,
                thumbnailFilename: entry.sheet.thumbnailFilename, bundledIndex: nil), entry.sheet.difficulty)
            appModel.closeSongSelection()
        }

        private func findEntry(for song: SongSummary, matchingDifficulty diff: String) -> BundledSheet? {
            // Prefer exact match of difficulty string (case-sensitive)
            let candidates = appModel.bundledSheets.filter { $0.sheet.title == song.title }
            if let exact = candidates.first(where: { ($0.sheet.difficulty ?? "") == diff }) {
                return exact
            }
            // fallback: try case-insensitive match
            if let ci = candidates.first(where: { ($0.sheet.difficulty ?? "").lowercased() == diff.lowercased() }) {
                return ci
            }
            // fallback: if diff is a number (e.g. "4" or "Level 4"), attempt to match numeric suffix
            let numeric = diff.compactMap { $0.wholeNumberValue }.map { String($0) }.joined()
            if !numeric.isEmpty {
                if let byNum = candidates.first(where: {
                    let s = ($0.sheet.difficulty ?? "")
                    return s.contains(numeric) || s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined() == numeric
                }) {
                    return byNum
                }
            }
            // nothing matched
            return nil
        }

        // When user taps a carousel tile we either pick the only candidate, or show a difficulty picker
        private func selectOrShowPicker(for song: SongSummary) {
            let candidates = appModel.bundledSheets.filter { $0.sheet.title == song.title }
            if candidates.isEmpty {
                if let idx = song.bundledIndex, appModel.bundledSheets.indices.contains(idx) {
                    performSelect(entry: appModel.bundledSheets[idx], forSongTitle: song.title)
                } else {
                    print("DBG: No candidate sheets found for \(song.title)")
                }
                return
            }

            if candidates.count == 1 {
                performSelect(entry: candidates[0], forSongTitle: song.title)
                return
            }

            // multiple difficulties available -> show confirmation dialog
            difficultyCandidates = candidates.sorted { ($0.sheet.difficulty ?? "") < ($1.sheet.difficulty ?? "") }
            pendingSongTitle = song.title
            showingDifficultyPicker = true
        }

        private func onCancelIfNeeded() {
            if focusedIndex == nil {
                onCancel()
            }
        }

        private func closeFocus() {
            focusedIndex = nil
            showDifficulty = false
            dragOffsetY = 0
        }

        // Simple bundle image lookup
        // Simple bundle image lookup (fixed ternary operator)
        private func bundleImageURL(named imageFilename: String) -> URL? {
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

        // Minimal import handler (kept for parity)
        func handleImportedFile(url: URL) {
            DispatchQueue.global(qos: .userInitiated).async {
                var didStart = false
                if url.startAccessingSecurityScopedResource() {
                    didStart = true
                }
                defer {
                    if didStart { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let fm = FileManager.default
                    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let dest = docs.appendingPathComponent(url.lastPathComponent)
                    if fm.fileExists(atPath: dest.path) {
                        try fm.removeItem(at: dest)
                    }
                    try fm.copyItem(at: url, to: dest)
                    print("DBG: imported file copied to Documents: \(dest)")
                } catch {
                    print("DBG: import failed: \(error)")
                }
            }
        }
    }
}
