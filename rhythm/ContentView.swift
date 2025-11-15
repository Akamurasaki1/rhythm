//
//  ContentView.swift
//  rhythm
//
//  Created by Karen Naito on 2025/11/15.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// Models.swift の Note / Sheet / SheetNote を使う前提
// （このファイルはあなたが渡した ContentView を最小修正したもの）
/// メイン画面：ContentView 相当（ファイル名が MainView.swift ですが中身は ContentView）
struct ContentView: View {
    // ActiveNote: 表示用インスタンス（spawn 時に id が決まる）
    // --- Replace ActiveNote definition with this ---
    private struct ActiveNote: Identifiable {
        let id: UUID
        let sourceID: String?        // <- 追加: 譜面側の note.id を保持する
        let angleDegrees: Double
        var position: CGPoint
        let targetPosition: CGPoint
        let hitTime: Double
        let spawnTime: Double
        var isClear: Bool
    }
    // 組み込み sample データは空にする（別プロジェクトでは「新たに入れたデータのみ」を扱う）
    private let sampleDataSets: [[Note]] = []

    // Combine 表示数（組み込みサンプル + bundled-sheets 内の譜面）
    private var sampleCount: Int { sampleDataSets.count + bundledSheets.count }

    // UI / 状態
    @State private var selectedSampleIndex: Int = 0
    @State private var notesToPlay: [Note] = []

    @State private var activeNotes: [ActiveNote] = []
    @State private var isPlaying = false
    @State private var startDate: Date?
    @State private var showingEditor = false

    @State private var isShowingShare = false
    @State private var shareURL: URL? = nil

    @State private var isShowingImportPicker = false
    @State private var importErrorMessage: String? = nil

    // バンドル内の譜面 (filename, Sheet)
    @State private var bundledSheets: [(filename: String, sheet: Sheet)] = []

    // audio player
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var currentlyPlayingAudioFilename: String? = nil
    // プロパティ
    @State private var preparedAudioPlayer: AVAudioPlayer?
    @State private var audioStartDeviceTime: TimeInterval? = nil

    // persistent test player for debugging (keeps player alive)
    @State private var testPlayer: AVAudioPlayer? = nil

    // スケジュール管理
    @State private var scheduledWorkItems: [DispatchWorkItem] = []
    @State private var autoDeleteWorkItems: [UUID: DispatchWorkItem] = [:]

    // 重複カウント防止
    @State private var flickedNoteIDs: Set<UUID> = []

    // スコア / コンボ
    @State private var score: Int = 0
    @State private var combo: Int = 0

    // パラメータ（プレイ中は隠す）
    @State private var approachDistanceFraction: Double = 0.25
    @State private var approachSpeed: Double = 800.0

    // 判定窓
    private let perfectWindow: Double = 0.5
    private let goodWindowBefore: Double = 0.8
    private let goodWindowAfter: Double = 1.0

    // ノーツの寿命（spawn からの秒）
    private let lifeDuration: Double = 2.5

    // フリック判定パラメータ
    private let speedThreshold: CGFloat = 35.0
    private let hitRadius: CGFloat = 110.0

    // 見た目
    private let rodWidth: CGFloat = 160
    private let rodHeight: CGFloat = 10

    // 判定フィードバック
    @State private var lastJudgement: String = ""
    @State private var lastJudgementColor: Color = .white
    @State private var showJudgementUntil: Date? = nil

    // Carousel settings (reuse earlier cylinder-like UI)
    private let repeatFactor = 3
    @State private var initialScrollPerformed = false
    private let carouselItemWidth: CGFloat = 100
    private let carouselItemSpacing: CGFloat = 12
    // ContentView 内に追加する関数
    private func prepareAudioIfNeeded(named audioFilename: String?) {
        guard let audioFilename = audioFilename, !audioFilename.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = bundleURLForAudio(named: audioFilename) else {
                print("DBG: prepareAudioIfNeeded: audio not found for \(audioFilename)")
                return
            }
            do {
                let p = try AVAudioPlayer(contentsOf: url)
                p.prepareToPlay()
                DispatchQueue.main.async {
                    // 保持しておく（start 時に使い回す）
                    self.preparedAudioPlayer = p
                    print("DBG: prepared audio for \(audioFilename)")
                }
            } catch {
                print("DBG: prepareAudioIfNeeded failed: \(error)")
            }
        }
    }
    // --- helper: try to find audio in bundle or Documents (modified) ---
    private func bundleURLForAudio(named audioFilename: String?) -> URL? {
        guard let audioFilename = audioFilename, !audioFilename.isEmpty else { return nil }
        // split name/ext
        let ext = (audioFilename as NSString).pathExtension
        let name = (audioFilename as NSString).deletingPathExtension

        // try app bundle first (root or bundled-audio)
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext, subdirectory: "bundled-audio") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext) {
            return url
        }

        // fallback: check Documents folder (imported audio)
        let candidates = try? FileManager.default.contentsOfDirectory(at: SheetFileManager.documentsURL, includingPropertiesForKeys: nil, options: [])
        if let c = candidates {
            if let found = c.first(where: { $0.deletingPathExtension().lastPathComponent == name && $0.pathExtension == (ext.isEmpty ? "wav" : ext) }) {
                return found
            }
            // try matching name regardless of ext
            if let found = c.first(where: { $0.deletingPathExtension().lastPathComponent == name }) {
                return found
            }
        }
        return nil
    }

    // --- bundled-sheets loader: read JSON from Documents folder only (new project uses imported files) ---
    private func loadBundledSheets() -> [(filename: String, sheet: Sheet)] {
        var results: [(String, Sheet)] = []
        let decoder = JSONDecoder()

        // 1) try subdirectory "bundled-sheets"
        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets") {
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let s = try decoder.decode(Sheet.self, from: data)
                    results.append((url.lastPathComponent, s))
                } catch {
                    print("Failed decode bundled sheet at \(url): \(error)")
                }
            }
        }

        // 2) fallback: try any json in bundle root
        if results.isEmpty {
            if let rootUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
                for url in rootUrls {
                    // skip hidden/system files
                    let filename = url.lastPathComponent
                    if filename.hasPrefix(".") { continue }
                    do {
                        let data = try Data(contentsOf: url)
                        let s = try decoder.decode(Sheet.self, from: data)
                        if !results.contains(where: { $0.0 == filename }) {
                            results.append((filename, s))
                        }
                    } catch {
                        print("Failed decode root bundle sheet at \(url)")
                    }
                }
            }
        }

        // 3) also look in Documents (imported JSON)
        do {
            let docUrls = try FileManager.default.contentsOfDirectory(at: SheetFileManager.documentsURL, includingPropertiesForKeys: nil, options: [])
            for url in docUrls where url.pathExtension.lowercased() == "json" {
                let filename = url.lastPathComponent
                do {
                    let data = try Data(contentsOf: url)
                    let s = try decoder.decode(Sheet.self, from: data)
                    if !results.contains(where: { $0.0 == filename }) {
                        results.append((filename, s))
                    }
                } catch {
                    print("Failed decode sheet at Documents \(url): \(error)")
                }
            }
        } catch {
            // ignore
        }

        print("loadBundledSheets -> found \(results.count) sheets: \(results.map { $0.0 })")
        return results
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 上段: スコア / コンボ / 判定表示
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Score: \(score)")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("Combo: \(combo)")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                        }
                        Spacer()
                        if shouldShowJudgement() {
                            Text(lastJudgement)
                                .font(.title2)
                                .bold()
                                .foregroundColor(lastJudgementColor)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Sample ラベル + カルーセル（再生中は非表示）
                    HStack(alignment: .center) {
                        Text("Sample:")
                            .foregroundColor(.white)
                            .padding(.leading, 10)

                        if !isPlaying {
                            carouselView(width: geo.size.width)
                                .frame(height: 120)
                                .padding(.trailing, 8)
                        } else {
                            Spacer().frame(height: 8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)

                    // 調整 UI（再生中は隠す）
                    if !isPlaying {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Approach dist (fraction): \(String(format: "%.2f", approachDistanceFraction))")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            Slider(value: $approachDistanceFraction, in: 0.05...1.5)

                            HStack {
                                Text("Approach speed (pts/s): \(Int(approachSpeed))")
                                    .foregroundColor(.white)
                                Spacer()
                                let exampleDistance = approachDistanceFraction * min(geo.size.width, geo.size.height)
                                let derivedDuration = exampleDistance / max(approachSpeed, 1.0)
                                Text("例 dur: \(String(format: "%.2f", derivedDuration))s")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $approachSpeed, in: 100...3000)
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                    }

                    Spacer()
                }

                // 表示中のノーツ
                ForEach(activeNotes) { a in
                    RodView(angleDegrees: a.angleDegrees)
                        .frame(width: rodWidth, height: rodHeight)
                        .opacity(a.isClear ? 1.0 : 0.35)
                        .position(a.position)
                        .zIndex(a.isClear ? 2 : 1)
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onEnded { value in
                                    handleFlick(for: a.id, dragValue: value, in: geo.size)
                                }
                        )
                }

                // ボトム操作類（Start/Stop と Reset は常時表示）
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if isPlaying {
                                stopPlayback()
                            } else {
                                // 選択中が bundled sheet ならその譜面を使う
                                if selectedSampleIndex >= sampleDataSets.count {
                                    let bundledIndex = selectedSampleIndex - sampleDataSets.count
                                    if bundledSheets.indices.contains(bundledIndex) {
                                        notesToPlay = bundledSheets[bundledIndex].sheet.notes.asNotes()
                                        prepareAudioIfNeeded(named: bundledSheets[bundledIndex].sheet.audioFilename)
                                    } else {
                                        notesToPlay = []
                                    }
                                } else {
                                    notesToPlay = []
                                }
                                startPlayback(in: geo.size)
                            }
                        }) {
                            Text(isPlaying ? "Stop" : "Start")
                                .font(.headline)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(isPlaying ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Spacer()
                            // Editor ボタン
                            Button(action: {
                                showingEditor = true
                            }) {
                                Text("Editor")
                                    .font(.subheadline)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            Spacer()
                        // Export (placeholder)
                        do {
                            Text("Export")
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.purple.opacity(0.85))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }

                        Spacer()

                        Button(action: {
                            isShowingImportPicker = true
                        }) {
                            Text("Import")
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.orange.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        Button(action: {
                            resetAll()
                        }) {
                            Text("Reset")
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                .sheet(isPresented: $showingEditor) {
                    SheetEditorView()
                }
                    .padding(.bottom, 16)

                    if !isPlaying {
                        HStack {
                            Text("Selected: \(selectedSampleIndex + 1)")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    } else {
                        Spacer().frame(height: 20)
                    }
                }
            }
            // グローバルフリック検出
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        handleGlobalFlick(dragValue: value, in: geo.size)
                    }
            )
            // file importer: JSON / audio を受け取れるように
            .fileImporter(isPresented: $isShowingImportPicker,
                          allowedContentTypes: [UTType.json, UTType.audio],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    handleImportedFile(url: url)
                case .failure(let err):
                    importErrorMessage = "Import picker failed: \(err.localizedDescription)"
                }
            }
            
            .onAppear {
                // load bundledSheets first, then select
                bundledSheets = loadBundledSheets()
                if !bundledSheets.isEmpty {
                    selectedSampleIndex = sampleDataSets.count // 最初の bundled sheet を選択
                }

                // デバッグ用（onAppear 内か load 完了時に呼ぶ）
                let jsonUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets") ?? []
                print("Bundle: found json in bundled-sheets: \(jsonUrls.map { $0.lastPathComponent })")

                if let audioURL = bundleURLForAudio(named: "mopemope.wav") {
                    print("Bundle: found audio: \(audioURL.lastPathComponent) at \(audioURL)")
                } else {
                    print("Bundle: audio NOT found for mopemope.wav")
                }

                // quick persistent audio test (keeps player in state so we can verify playback)

            }
            .sheet(isPresented: $isShowingShare, onDismiss: {
                shareURL = nil
            }) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                } else {
                    Text("No file to share.")
                }
            }
        }
    }

    // MARK: - Carousel (円柱風ループ)
    @ViewBuilder
    private func carouselView(width: CGFloat) -> some View {
        // combined entries: built-in first, then bundledSheets
        let entriesCount = max(1, sampleCount)
        let total = entriesCount * repeatFactor
        let initialIndex = entriesCount * (repeatFactor / 2)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: carouselItemSpacing) {
                    ForEach(0..<total, id: \.self) { i in
                        let sampleIndex = i % entriesCount
                        GeometryReader { itemGeo in
                            let frame = itemGeo.frame(in: .global)
                            let centerX = UIScreen.main.bounds.width / 2
                            let midX = frame.midX
                            let diff = midX - centerX
                            let normalized = max(-1.0, min(1.0, diff / (width * 0.5)))
                            let rotateDeg = -normalized * 30.0
                            let scale = 1.0 - abs(normalized) * 0.25
                            let opacity = 1.0 - abs(normalized) * 0.6

                            VStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedSampleIndex == sampleIndex ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: carouselItemWidth, height: 64)
                                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                                    Text(sampleLabel(for: sampleIndex))
                                        .foregroundColor(.white)
                                        .bold()
                                }
                            }
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .rotation3DEffect(.degrees(rotateDeg), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                            .onTapGesture {
                                // 譜面を選んだとき（carousel の onTap 内など）
                                func prepareAudioIfNeeded(named filename: String) {
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        guard let url = bundleURLForAudio(named: filename) else { return }
                                        do {
                                            let p = try AVAudioPlayer(contentsOf: url)
                                            p.prepareToPlay()
                                            DispatchQueue.main.async {
                                                self.preparedAudioPlayer = p
                                                print("DBG: prepared audio for \(filename)")
                                            }
                                        } catch {
                                            print("DBG: prepare failed: \(error)")
                                        }
                                    }
                                }
                                withAnimation {
                                    selectedSampleIndex = sampleIndex
                                    let target = entriesCount * (repeatFactor / 2) + sampleIndex
                                    proxy.scrollTo(target, anchor: .center)

                                    // preview: update notesToPlay for non-playing preview
                                    if !isPlaying {
                                        if sampleIndex >= sampleDataSets.count {
                                            let bidx = sampleIndex - sampleDataSets.count
                                            if bundledSheets.indices.contains(bidx)
                                            {
                                                notesToPlay = bundledSheets[bidx].sheet.notes.asNotes()
                                            }
                                        } else {
                                            notesToPlay = []
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: carouselItemWidth, height: 80)
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

    private func sampleLabel(for index: Int) -> String {
        // built-in samples first
        if index < sampleDataSets.count {
            return "No.\(index + 1)"
        }
        // then bundled sheet titles
        let bidx = index - sampleDataSets.count
        if bundledSheets.indices.contains(bidx) {
            return bundledSheets[bidx].sheet.title
        }
        return "No.\(index + 1)"
    }

    private func shouldShowJudgement() -> Bool {
        if let until = showJudgementUntil {
            return Date() <= until
        }
        return false
    }

    // Paste these functions into ContentView (methods area)

    func handleImportedFile(url: URL) {
        // DocumentPicker may give security-scoped url (sandbox). We attempt to copy it into Documents.
        DispatchQueue.global(qos: .userInitiated).async {
            var didStart = false
            if url.startAccessingSecurityScopedResource() {
                didStart = true
            }
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let destURL = SheetFileManager.documentsURL.appendingPathComponent(url.lastPathComponent)
            do {
                // If file exists, append a numeric suffix to avoid overwrite
                var finalDest = destURL
                var idx = 1
                while FileManager.default.fileExists(atPath: finalDest.path) {
                    let base = destURL.deletingPathExtension().lastPathComponent
                    let ext = destURL.pathExtension
                    let newName = "\(base)_\(idx).\(ext)"
                    finalDest = SheetFileManager.documentsURL.appendingPathComponent(newName)
                    idx += 1
                }

                // Copy selected file to app Documents folder
                try FileManager.default.copyItem(at: url, to: finalDest)
                print("Imported file copied to: \(finalDest.path)")

                // reload samples/UI on main thread
                DispatchQueue.main.async {
                    bundledSheets = loadBundledSheets()
                }
            } catch {
                DispatchQueue.main.async {
                    importErrorMessage = "Import failed: \(error.localizedDescription)"
                }
                print("Import copy failed: \(error)")
            }
        }
    }

    // MARK: - Playback (spawn/clear/delete を整理してスケジュール)
    private func startPlayback(in size: CGSize) {
        // startPlayback の冒頭に追加（既にある場合は不要）
        if testPlayer?.isPlaying == true {
            testPlayer?.stop()
        }
        testPlayer = nil
        print("DBG: startPlayback entered isPlaying=\(isPlaying) selectedIndex=\(selectedSampleIndex) sampleDataSetsCount=\(sampleDataSets.count) bundledSheetsCount=\(bundledSheets.count)")
        if selectedSampleIndex >= sampleDataSets.count {
            let bidx = selectedSampleIndex - sampleDataSets.count
            print("DBG: selected bundled index = \(bidx), bundled sheet filename = \(bundledSheets.indices.contains(bidx) ? bundledSheets[bidx].filename : "out-of-range")")
        }
        guard !isPlaying else { return }

        // set up AVAudioSession and AVAudioPlayer if we have audio (try to find audio for bundled sheet if selected)
        var audioURL: URL? = nil
        var sheetForOffset: Sheet? = nil
        if selectedSampleIndex >= sampleDataSets.count {
            let bidx = selectedSampleIndex - sampleDataSets.count
            if bundledSheets.indices.contains(bidx) {
                sheetForOffset = bundledSheets[bidx].sheet
                if let audioName = sheetForOffset?.audioFilename {
                    // resolve audio filename -> url early so we can log
                    let found = bundleURLForAudio(named: audioName)
                    print("DBG: bundleURLForAudio(\"\(audioName)\") -> \(String(describing: found))")
                    audioURL = found
                } else {
                    print("DBG: selected sheet has no audioFilename")
                }
            }
        }

        if let url = audioURL {
            // debug
            print("DBG: sheetForOffset = \(String(describing: sheetForOffset))")
            print("DBG: sheetForOffset.audioFilename = \(String(describing: sheetForOffset?.audioFilename))")
            print("DEBUG: resolved audioURL = \(String(describing: audioURL))")

            // Ensure AVAudioSession is active (attempt once; avoid repeated heavy activate)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("DEBUG: AVAudioSession setup failed (ignored): \(error)")
            }

            // If we have a prepared player for the same URL, use it; otherwise create one
            if let p = preparedAudioPlayer, p.url == url {
                audioPlayer = p
                preparedAudioPlayer = nil
                audioPlayer?.currentTime = 0
            } else {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.prepareToPlay()
                } catch {
                    print("DEBUG: Audio prepare failed: \(error)")
                    audioPlayer = nil
                }
            }

            // If we have an audio player, schedule it to play at a device time in the near future
            if let player = audioPlayer {
                // compute a safe lead time based on audio session latency / io buffer
                let session = AVAudioSession.sharedInstance()
                let deviceNow = player.deviceCurrentTime
                let leadTime = max(0.05, session.outputLatency + session.ioBufferDuration + 0.02) // ~50ms minimal
                let startAt = deviceNow + leadTime

                // schedule audio to start at startAt
                player.play(atTime: startAt)
                audioStartDeviceTime = startAt
                print("DEBUG: scheduled audio play at device time \(startAt) (deviceNow \(deviceNow), lead \(leadTime))")
                currentlyPlayingAudioFilename = url.lastPathComponent
            } else {
                currentlyPlayingAudioFilename = nil
                audioStartDeviceTime = nil
            }
        } else {
            currentlyPlayingAudioFilename = nil
            audioStartDeviceTime = nil
        }

        // Now schedule notes
        isPlaying = true
        startDate = Date()
        activeNotes.removeAll()
        flickedNoteIDs.removeAll()

        // cancel previous scheduled
        scheduledWorkItems.forEach { $0.cancel() }
        scheduledWorkItems.removeAll()
        autoDeleteWorkItems.values.forEach { $0.cancel() }
        autoDeleteWorkItems.removeAll()

        // デバッグ出力・バリデーション追加版
        print("notesToPlay count:", notesToPlay.count)
        for (i,n) in notesToPlay.enumerated() {
            print(" note[\(i)]: id=\(n.id ?? "nil") time=\(n.time) pos=\(n.normalizedPosition) angle=\(n.angleDegrees)")
        }
        print("startPlayback: scheduling \(notesToPlay.count) notes")
        for (i, note) in notesToPlay.enumerated() {
            print("note[\(i)]: time=\(note.time), angle=\(note.angleDegrees), normalized=\(note.normalizedPosition)")

            // normalizedPosition の妥当性チェック（NaN / infinite / 範囲外）
            let nx = note.normalizedPosition.x
            let ny = note.normalizedPosition.y
            if nx.isNaN || ny.isNaN || nx.isInfinite || ny.isInfinite {
                print("Skipping note[\(i)] due to invalid normalizedPosition: \(note.normalizedPosition)")
                continue
            }
            // 画面外へ出るような値を含むなら clamp する or skip（ここでは clamp）
            let clampedX = min(max(0.0, nx), 1.0)
            let clampedY = min(max(0.0, ny), 1.0)

            let approachDistance = approachDistanceFraction * min(size.width, size.height)
            let approachDuration = approachDistance / max(approachSpeed, 1.0)
            let spawnTime = max(0.0, note.time - approachDuration)

            let target = CGPoint(x: clampedX * size.width,
                                 y: clampedY * size.height)

            // angle の妥当性（NaN 等）もチェック
            if note.angleDegrees.isNaN || note.angleDegrees.isInfinite {
                print("Skipping note[\(i)] due to invalid angleDegrees: \(note.angleDegrees)")
                continue
            }


            let theta = CGFloat(note.angleDegrees) * .pi / 180.0
            let rodDir = CGPoint(x: cos(theta), y: sin(theta))
            // ここは一方向から進入（v12 の感触）
            let n1 = CGPoint(x: -rodDir.y, y: rodDir.x)
            let startPos = CGPoint(x: target.x - n1.x * approachDistance,
                                   y: target.y - n1.y * approachDistance)

            // spawn: ノートを追加してアニメーションで移動開始
            let spawnWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    // --- In startPlayback, inside spawnWork when creating new ActiveNote ---
                    let newID = UUID()
                    let new = ActiveNote(
                        id: newID,
                        sourceID: note.id,           // <- ここで元ノーツの id を渡す
                        angleDegrees: note.angleDegrees,
                        position: startPos,
                        targetPosition: target,
                        hitTime: note.time,
                        spawnTime: spawnTime,
                        isClear: false
                    )
                    self.activeNotes.append(new)

                    // アプローチ移動は withAnimation(.linear(duration:))
                    if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                        withAnimation(.linear(duration: approachDuration)) {
                            self.activeNotes[idx].position = target
                        }
                    }

                    // spawn 実行時に deleteWork を生成して id に紐付け、spawn から lifeDuration 後に実行する
                    let deleteWork = DispatchWorkItem {
                        DispatchQueue.main.async {
                            // Miss 判定: まだフリックされていなければ消す
                            if self.activeNotes.firstIndex(where: { $0.id == newID }) != nil {
                                if self.flickedNoteIDs.contains(newID) {
                                    self.autoDeleteWorkItems[newID] = nil
                                    return
                                }
                                withAnimation(.easeIn(duration: 0.18)) {
                                    self.activeNotes.removeAll { $0.id == newID }
                                }
                                // Miss の振る舞い
                                self.combo = 0
                                self.autoDeleteWorkItems[newID] = nil
                                self.showJudgement(text: "MISS", color: .red)
                            }
                        }
                    }
                    // store and schedule deleteWork relative to now (spawn moment)
                    self.autoDeleteWorkItems[newID] = deleteWork
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.lifeDuration, execute: deleteWork)
                }
            }

            // clear: hitTime に鮮明表示にする
            // --- clearWork: use sourceID match when available, fallback to time/position match ---
            let clearWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    // Try to find by sourceID first (if notesToPlay items had ids)
                    var foundIndex: Int? = nil
                    if let sheetNoteID = ( /* NOTE: this closure captures `note` from for-loop */ note.id ) {
                        foundIndex = self.activeNotes.firstIndex(where: { $0.sourceID == sheetNoteID })
                    }
                    // Fallback: previous behavior (match by hitTime + targetPosition)
                    if foundIndex == nil {
                        foundIndex = self.activeNotes.firstIndex(where: { $0.hitTime == note.time && $0.targetPosition == target })
                    }
                    if let idx = foundIndex {
                        withAnimation(.easeOut(duration: 0.12)) {
                            self.activeNotes[idx].isClear = true
                        }
                    }
                }
            }

            // schedule
            scheduledWorkItems.append(spawnWork)
            scheduledWorkItems.append(clearWork)
            // schedule using audio device clock if available
            if let player = audioPlayer, let startDevice = audioStartDeviceTime {
                // current device time
                let deviceNow = player.deviceCurrentTime

                // spawnTime is relative to audio start
                let spawnDeviceTime = startDevice + spawnTime
                let clearDeviceTime = startDevice + note.time

                let spawnDelay = max(0.0, spawnDeviceTime - deviceNow)
                let clearDelay = max(0.0, clearDeviceTime - deviceNow)

                DispatchQueue.main.asyncAfter(deadline: .now() + spawnDelay, execute: spawnWork)
                DispatchQueue.main.asyncAfter(deadline: .now() + clearDelay, execute: clearWork)
            } else {
                // fallback: previous behavior (no audio sync available)
                DispatchQueue.main.asyncAfter(deadline: .now() + spawnTime, execute: spawnWork)
                DispatchQueue.main.asyncAfter(deadline: .now() + note.time, execute: clearWork)
            }
        }

        // 最後のノート後に isPlaying を false に戻す（余裕タイム）
        if let last = notesToPlay.map({ $0.time }).max() {
            let finishDelay = last + lifeDuration + 0.5
            let finishWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.scheduledWorkItems.removeAll()
                    // cancel any auto-delete
                    self.autoDeleteWorkItems.values.forEach { $0.cancel() }
                    self.autoDeleteWorkItems.removeAll()

                    // stop audio when finished
                    if audioPlayer?.isPlaying == true {
                        audioPlayer?.stop()
                    }
                    audioPlayer = nil
                    currentlyPlayingAudioFilename = nil
                }
            }
            scheduledWorkItems.append(finishWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay, execute: finishWork)
        }
    }

    private func stopPlayback() {
        // stop audio
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
        currentlyPlayingAudioFilename = nil

        // existing cleanup
        for w in scheduledWorkItems { w.cancel() }
        scheduledWorkItems.removeAll()
        autoDeleteWorkItems.values.forEach { $0.cancel() }
        autoDeleteWorkItems.removeAll()
        isPlaying = false
        startDate = nil
    }
    private func stopAudioIfPlaying() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
        currentlyPlayingAudioFilename = nil
    }
    private func resetAll() {
        stopPlayback()
        withAnimation(.easeOut(duration: 0.15)) {
            activeNotes.removeAll()
        }
        score = 0
        combo = 0
        flickedNoteIDs.removeAll()
        lastJudgement = ""
        showJudgementUntil = nil
    }

    // MARK: - フリック処理（v12 の見た目に近づける）
    private func handleFlick(for id: UUID, dragValue: DragGesture.Value, in size: CGSize) {
        // 既にフリック済みなら無視
        if flickedNoteIDs.contains(id) { return }

        let predicted = dragValue.predictedEndTranslation
        let flickVec = CGPoint(x: predicted.width, y: predicted.height)
        let flickSpeed = hypot(flickVec.x, flickVec.y)
        guard flickSpeed > speedThreshold else { return }

        guard let idx = activeNotes.firstIndex(where: { $0.id == id }) else { return }
        let note = activeNotes[idx]

        // 棒の向きから法線を作り、どっち側に飛ばすか判断
        let theta = CGFloat(note.angleDegrees) * .pi / 180.0
        let rodDir = CGPoint(x: cos(theta), y: sin(theta))
        let n1 = CGPoint(x: -rodDir.y, y: rodDir.x)
        let n2 = CGPoint(x: rodDir.y, y: -rodDir.x)
        let dot1 = n1.x * flickVec.x + n1.y * flickVec.y
        let dot2 = n2.x * flickVec.x + n2.y * flickVec.y
        let chosenNormal: CGPoint = (dot1 >= dot2) ? n1 : n2

        // 飛ばすターゲット（画面外へ）
        let distance = max(size.width, size.height) * 1.5
        let target = CGPoint(x: note.position.x + chosenNormal.x * distance,
                             y: note.position.y + chosenNormal.y * distance)

        // cancel auto-delete for this note
        if let work = autoDeleteWorkItems[id] {
            work.cancel()
            autoDeleteWorkItems[id] = nil
        }

        // mark flicked (prevent double)
        flickedNoteIDs.insert(id)

        // 判定（経過時間 vs hitTime）
        // 以前: let elapsed = startDate.map { Date().timeIntervalSince($0) } ?? 0.0
        var elapsed: TimeInterval = 0.0
        if let player = audioPlayer, let startDev = audioStartDeviceTime {
            elapsed = player.deviceCurrentTime - startDev
        } else if let sd = startDate {
            elapsed = Date().timeIntervalSince(sd)
        }
        let dt = elapsed - note.hitTime

        var judgementText = "OK"
        var judgementColor: Color = .white
        if abs(dt) <= perfectWindow {
            judgementText = "PERFECT"; judgementColor = .green
        } else if (dt >= -goodWindowBefore && dt < -perfectWindow) || (dt > perfectWindow && dt <= goodWindowAfter) {
            judgementText = "GOOD"; judgementColor = .blue
        } else {
            judgementText = "OK"; judgementColor = .white
        }

        // スコア/コンボ
        score += 1
        combo += 1
        showJudgement(text: judgementText, color: judgementColor)

        // フリック後の飛翔は v12 っぽく easing で飛ばす
        let flyDuration: Double = 0.6
        withAnimation(.easeOut(duration: flyDuration)) {
            if let idx2 = activeNotes.firstIndex(where: { $0.id == id }) {
                activeNotes[idx2].position = target
            }
        }

        // 飛び切ったら削除
        DispatchQueue.main.asyncAfter(deadline: .now() + flyDuration + 0.05) {
            withAnimation(.easeIn(duration: 0.12)) {
                self.activeNotes.removeAll { $0.id == id }
            }
            // optional cleanup
            self.flickedNoteIDs.remove(id)
        }
    }

    // グローバルフリック: 開始位置に最も近いノーツが hitRadius 内なら処理
    private func handleGlobalFlick(dragValue: DragGesture.Value, in size: CGSize) {
        let predicted = dragValue.predictedEndTranslation
        let flickVec = CGPoint(x: predicted.width, y: predicted.height)
        let flickSpeed = hypot(flickVec.x, flickVec.y)
        guard flickSpeed > speedThreshold else { return }

        let start = dragValue.startLocation

        var closestId: UUID?
        var closestDist = CGFloat.greatestFiniteMagnitude
        for n in activeNotes {
            let d = hypot(n.position.x - start.x, n.position.y - start.y)
            if d < closestDist {
                closestDist = d
                closestId = n.id
            }
        }

        if let id = closestId, closestDist <= hitRadius {
            handleFlick(for: id, dragValue: dragValue, in: size)
        }
    }

    // 判定を一時表示
    private func showJudgement(text: String, color: Color) {
        lastJudgement = text
        lastJudgementColor = color
        showJudgementUntil = Date().addingTimeInterval(0.8)
    }
}

struct RodView: View {
    let angleDegrees: Double

    var body: some View {
        Rectangle()
            .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray]),
                                 startPoint: .leading, endPoint: .trailing))
            .cornerRadius(5)
            .shadow(color: Color.white.opacity(0.2), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(angleDegrees))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
