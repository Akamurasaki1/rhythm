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
        // タップノーツ用追加:
        var isTap: Bool = false
        var isHold: Bool = false
        // タップノーツは上下2つの三角を持つ -> position は上側三角の位置、position2 は下側三角
        var position2: CGPoint? = nil
        // hold: end time (device/audio time coordinate: use sheet.holdEndTime)
        var holdEndTime: Double? = nil
        // hold runtime flags
        var holdStarted: Bool = false  // set when player started holding
        // 既存 ActiveNote に追加
        var holdFillScale: Double = 0.0   // 内側の実円が 0.0->1.0 で拡大
        var holdTrim: Double = 1.0        // ホールド中の残り割合 (1.0 = 全円、0.0 = 無し)
    }
    // 組み込み sample データは空にする（別プロジェクトでは「新たに入れたデータのみ」を扱う）
    private let sampleDataSets: [[Note]] = []
    
    // Combine 表示数（組み込みサンプル + bundled-sheets 内の譜面）
    private var sampleCount: Int { sampleDataSets.count + bundledSheets.count }
    
    // UI / 状態
    @State private var selectedSampleIndex: Int = 0
    @State private var notesToPlay: [Note] = []
    // notesToPlay (表示用の簡易 Note 配列) は残してもよいが、スケジューリングは sheetNotes を使う
    @State private var sheetNotesToPlay: [SheetNote] = []
    
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
    // 追加: ContentView の @State 群に入れる（他の @State と同じブロック）
    @State private var cumulativeCombo: Int = 0 // 通算コンボ
    @State private var consecutiveCombo: Int = 0 // 通算連続コンボ
    @State private var maxCombo: Int = 0 // 今回のプレイでの最大コンボ
    @State private var playMaxHistory: [Int] = [] // 各プレイの最大コンボ履歴
    @State private var perfectCount: Int = 0
    @State private var goodCount: Int = 0
    @State private var okCount: Int = 0
    @State private var missCount: Int = 0
    
    // プレイ終了後に集計を見せるフラグ
    @State private var isShowingResults: Bool = false
    
    // パラメータ（プレイ中は隠す）
    @State private var approachDistanceFraction: Double = 0.25
    @State private var approachSpeed: Double = 800.0
    
    // 判定窓
    private let perfectWindow: Double = 0.6
    private let goodWindowBefore: Double = 0.8
    private let goodWindowAfter: Double = 1.0
    
    // ノーツの寿命（spawn からの秒）
    private let lifeDuration: Double = 2.5
    
    // フリック判定パラメータ
    private let speedThreshold: CGFloat = 35.0
    private let hitRadius: CGFloat = 110.0
    // タッチ/長押し検出のための State
    @State private var touchStartTime: Date? = nil
    @State private var touchStartLocation: CGPoint? = nil
    @State private var touchIsLongPress: Bool = false
    @State private var touchLongPressWorkItem: DispatchWorkItem? = nil
    // hold 用進捗更新タイマーを保持（DispatchSourceTimer）
    @State private var holdTimers: [UUID: DispatchSourceTimer] = [:]
    // 長押し閾値（秒）
    private let longPressThreshold: TimeInterval = 0.35
    // 追加: ホールド内側の拡大にかける時間をアプローチ時間の何倍にするか
    // 1.0 = approachDuration（到達と同時にフルサイズになる）
    // 0.8 = 到達の 80% 時点でフルサイズにする（到達より早く開始される）
    // 値は 0.0..2.0 くらいを想定（必要なら絶対秒数の変数にしても良い）
    @State private var holdFillDurationFraction: Double = 1.0
    // --- 追加: View 上部の @State 群に入れてください ---
    // "白円が満杯になるまでの時間" = approachDuration * holdFillDurationFraction
    // 1.0 = approachDuration と同じ、0.8 = 到達の 80% 時点で満杯、など

    @State private var holdFinishTrimThreshold: Double = 0.02
    // 扇形 (holdTrim) がこの閾値以下になったらホールド完了（very thin）としてノートを削除します。
    // 0.02 = 2% 程度（要調整）
    private func handlePotentialLongPressStart(at location: CGPoint) {
        // stub: 長押し開始時に呼ばれる（後で hold ノーツ処理を入れる）
        // 将来: location 近傍にある hold ノーツを "holdStarted = true" にする等
        // print("DBG: long press start at \(location)")
    }

    private func handlePotentialLongPressEnd(at location: CGPoint, duration: TimeInterval) {
        // stub: 長押し終了時に呼ばれる（後で hold の成功判定を行う）
        // print("DBG: long press end at \(location), duration=\(duration)")
    }
    private func handleTap(at location: CGPoint, in _unused: CGPoint) {
        // オーディオ時刻基準
        var elapsed: TimeInterval = 0.0
        if let player = audioPlayer, let startDev = audioStartDeviceTime {
            elapsed = player.deviceCurrentTime - startDev
        } else if let sd = startDate {
            elapsed = Date().timeIntervalSince(sd)
        }

        // find nearest tap note near target
        var matchedIdx: Int? = nil
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (i, a) in activeNotes.enumerated() {
            guard a.isTap else { continue }
            let d = hypot(a.targetPosition.x - location.x, a.targetPosition.y - location.y)
            if d <= hitRadius && d < bestDist {
                bestDist = d
                matchedIdx = i
            }
        }

        guard let idx = matchedIdx else { return }
        let note = activeNotes[idx]
        let dt = elapsed - note.hitTime
        var judgementText = "OK"
        var judgementColor: Color = .white
        if abs(dt) <= perfectWindow {
            judgementText = "PERFECT"; judgementColor = .green;
            score += 3
        } else if (dt >= -goodWindowBefore && dt < -perfectWindow) || (dt > perfectWindow && dt <= goodWindowAfter) {
            judgementText = "GOOD"; judgementColor = .blue;
            score += 2
        } else {
            judgementText = "OK"; judgementColor = .white;
            score += 1
        }

        // scoring
        combo += 1
        if combo > maxCombo { maxCombo = combo }
        switch judgementText {
        case "PERFECT": perfectCount += 1
        case "GOOD": goodCount += 1
        case "OK": okCount += 1
        default: break
        }

        // visual + cancel auto-delete
        let noteID = note.id
        if let w = autoDeleteWorkItems[noteID] {
            w.cancel()
            autoDeleteWorkItems[noteID] = nil
        }
        withAnimation(.easeOut(duration: 0.12)) {
            self.activeNotes.removeAll { $0.id == noteID }
        }
        showJudgement(text: judgementText, color: judgementColor)
    }
    
    // 見た目
    private let rodWidth: CGFloat = 160
    private let rodHeight: CGFloat = 10
    
    // 判定フィードバック
    @State private var lastJudgement: String = ""
    @State private var lastJudgementColor: Color = .white
    @State private var showJudgementUntil: Date? = nil
    
    // Carousel settings (reuse earlier cylinder-like UI)
    private let repeatFactor = 1 // 円柱上で同じ曲は何回ループ？
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
                    print("Failed decode sheet at Documents \(url)")
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
                        Text("Songs:")
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
                    if a.isTap {
                        // タップノーツ: 上下三角
                        TriangleUp()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray]), startPoint: .top, endPoint: .bottom))
                            .frame(width: 44, height: 22)
                            .position(a.position)
                            .zIndex(3)
                        
                        TriangleDown()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray]), startPoint: .bottom, endPoint: .top))
                            .frame(width: 44, height: 22)
                            .position(a.position2 ?? a.targetPosition)
                            .zIndex(3)
                            .opacity(a.isClear ? 1.0 : 0.95)
                    } else if a.isHold {
                        // デフォルトサイズ（調整可）
                        let size: CGFloat = 64
                        // 中央位置に HoldView を描画（target に合わせる）
                        HoldView(size: size,
                                 fillScale: a.holdFillScale,
                                 trimProgress: a.holdTrim,
                                 ringColor: .white.opacity(0.9),
                                 fillColor: .white.opacity(0.95))
                        .position(a.targetPosition)
                        .zIndex(4)
                    }else{
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
                                        // 既往の notesToPlay = bundledSheets[bundledIndex].sheet.notes.asNotes()
                                        // の代わりに元の SheetNote 配列を保持
                                        sheetNotesToPlay = bundledSheets[bundledIndex].sheet.notes
                                        // （必要なら表示用に Note 型へ変換して notesToPlay にも入れる）
                                        notesToPlay = bundledSheets[bundledIndex].sheet.notes.asNotes()
                                    } else {
                                        sheetNotesToPlay = []
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // first touch event: set start time and schedule long press
                        if touchStartTime == nil {
                            touchStartTime = Date()
                            touchStartLocation = value.startLocation
                            touchIsLongPress = false

                            // schedule long-press marker
                            let work = DispatchWorkItem {
                                DispatchQueue.main.async {
                                    touchIsLongPress = true
                                    // notify potential long-press start (hook for future)
                                    handlePotentialLongPressStart(at: value.startLocation)
                                }
                            }
                            touchLongPressWorkItem?.cancel()
                            touchLongPressWorkItem = work
                            DispatchQueue.global().asyncAfter(deadline: .now() + longPressThreshold, execute: work)
                        }
                    }
                    .onEnded { value in
                        // cancel scheduled long press detection
                        touchLongPressWorkItem?.cancel()
                        touchLongPressWorkItem = nil

                        let start = touchStartTime ?? Date()
                        let duration = Date().timeIntervalSince(start)
                        let dx = value.location.x - (touchStartLocation?.x ?? value.location.x)
                        let dy = value.location.y - (touchStartLocation?.y ?? value.location.y)
                        let dist = hypot(dx, dy)

                        // if it was long press (work item fired), treat as long-press end
                        if touchIsLongPress {
                            handlePotentialLongPressEnd(at: value.location, duration: duration)
                        } else {
                            // short, treat as tap if finger didn't move much
                            if dist < 20.0 {
                                handleTap(at: value.location, in: value.startLocation) // you can pass geo.size if needed
                            } else {
                                // treat as flick if long drag
                                handleGlobalFlick(dragValue: value, in: UIScreen.main.bounds.size)
                            }
                        }

                        // reset touch state
                        touchStartTime = nil
                        touchStartLocation = nil
                        touchIsLongPress = false
                    }
            )
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
            // 表示用: 再生結果を sheet で表示
                          .sheet(isPresented: $isShowingResults, onDismiss: {
                              // 結果を閉じたときに必要ならリセット処理を入れる
                          }) {
                              VStack(spacing: 16) {
                                  Text("プレイ結果")
                                      .font(.title)
                                      .bold()
                                  HStack{
                                      Text("Score:   ").font(.title2).bold()
                                      Text("\(score)").font(.title2).bold()
                                  }
                                  HStack {
                                      Text("最大コンボ").font(.title2).bold()
                                      Spacer()
                                      Text("\(maxCombo)").font(.title2)
                                          .bold()
                                  }
                                  HStack {
                                      Text("PERFECT")
                                      Spacer()
                                      Text("\(perfectCount)")
                                  }
                                  HStack {
                                      Text("GOOD")
                                      Spacer()
                                      Text("\(goodCount)")
                                  }
                                  HStack {
                                      Text("OK")
                                      Spacer()
                                      Text("\(okCount)")
                                  }
                                  HStack {
                                      Text("MISS")
                                      Spacer()
                                      Text("\(missCount)")
                                  }
                                  Divider()
                                  HStack {
                                      Text("通算連続コンボ")
                                      Spacer()
                                      Text("\(consecutiveCombo)")
                                  }
                                  HStack {
                                      Text("通算コンボ")
                                      Spacer()
                                      Text("\(cumulativeCombo)")
                                  }
                                  
                                  
                                  Button(action: {
                                      isShowingResults = false
                                      
                                  }) {
                                      Text("閉じる")
                                          .bold()
                                          .frame(maxWidth: .infinity)
                                          .padding()
                                          .background(Color.blue.opacity(0.85))
                                          .foregroundColor(.white)
                                          .cornerRadius(8)
                                  }
                                  .padding(.top, 8)
                              }
                              .padding()
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
        // 変更: startPlayback の先頭（isPlaying の guard の手前または直後）で集計リセットを追加
        // 既に startPlayback 先頭に DBG: log を入れている箇所の直後が良いです。
        // start of a new play: reset per-play stats
        maxCombo = 0
        score = 0           // ← 追加: 前回のスコアをクリア
        combo = 0           // ← 追加: 前回のコンボをクリア
        perfectCount = 0
        goodCount = 0
        okCount = 0
        missCount = 0
        isShowingResults = false
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
        for (i, note) in sheetNotesToPlay.enumerated() {
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
            // === Replace the spawnWork block with this corrected version ===
            let spawnWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    // --- In startPlayback, inside spawnWork when creating new ActiveNote ---
                    let newID = UUID()

                    // note はループ変数を使う（sheet ではない）
                    let isTapNote = (note.noteType == "tap")
                    let isHoldNote = (note.noteType == "hold")

                    if isTapNote {
                        // タップ: 上下三角が target に向かってくる
                        let topStart = CGPoint(x: target.x, y: target.y - approachDistance - 60)
                        let bottomStart = CGPoint(x: target.x, y: target.y + approachDistance + 60)

                        let new = ActiveNote(
                            id: newID,
                            sourceID: note.id,
                            angleDegrees: 0.0,
                            position: topStart,
                            targetPosition: target,
                            hitTime: note.time,
                            spawnTime: spawnTime,
                            isClear: false,
                            isTap: true,
                            position2: bottomStart
                        )
                        self.activeNotes.append(new)

                        // 2つを同時に target に移動
                        if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                            withAnimation(.linear(duration: approachDuration)) {
                                self.activeNotes[idx].position = target
                                self.activeNotes[idx].position2 = target
                            }
                        }
                    } else if isHoldNote {
                        // Hold: start positions like tap, but mark holdEndTime
                        let topStart = CGPoint(x: target.x, y: target.y - approachDistance - 80)
                        let bottomStart = CGPoint(x: target.x, y: target.y + approachDistance + 80)

                        var new = ActiveNote(
                            id: newID,
                            sourceID: note.id,
                            angleDegrees: 0.0,
                            position: topStart,
                            targetPosition: target,
                            hitTime: note.time,
                            spawnTime: spawnTime,
                            isClear: false,
                            isTap: false,
                            isHold: true,
                            position2: bottomStart,
                            holdEndTime: note.holdEndTime
                        )
                        // 初期表示値
                        new.holdFillScale = 0.0
                        new.holdTrim = 1.0

                        self.activeNotes.append(new)
                        // holdFill の所要時間を決定
                            let fraction = max(0.0, min(2.0, self.holdFillDurationFraction))
                            let holdFillDuration = max(0.0, approachDuration * fraction)

                            // ①: 内側白円を 0 -> 1 にアニメーション（満杯になった瞬間をホールド開始とする）
                            if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                                withAnimation(.linear(duration: holdFillDuration)) {
                                    self.activeNotes[idx].holdFillScale = 1.0
                                }
                            }

                        // ②: 白円が満杯になったタイミングで "ホールド開始" として hold timer を起動
                        DispatchQueue.main.asyncAfter(deadline: .now() + holdFillDuration) {
                            // note がまだ残っているか確認
                            guard let idx2 = self.activeNotes.firstIndex(where: { $0.id == newID }) else { return }

                            // mark hold started (UI 用フラグ)
                            self.activeNotes[idx2].holdStarted = true

                            // create a timer that updates holdTrim (remaining fraction) at ~30Hz
                            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                            let interval = DispatchTimeInterval.milliseconds(33)
                            timer.schedule(deadline: .now(), repeating: interval)

                            timer.setEventHandler {
                                // note が存在するか再度確認
                                guard let idx3 = self.activeNotes.firstIndex(where: { $0.id == newID }) else {
                                    timer.cancel()
                                    self.holdTimers[newID] = nil
                                    return
                                }

                                // remainingFraction を計算（device clock 優先）
                                var remainingFraction: Double = 0.0
                                if let player = self.audioPlayer, let startDev = self.audioStartDeviceTime, let holdEnd = note.holdEndTime {
                                    // player.deviceCurrentTime はデバイス時刻
                                    let deviceNow = player.deviceCurrentTime
                                    let holdStartDev = startDev + note.time
                                    let holdEndDev = startDev + holdEnd
                                    let total = holdEndDev - holdStartDev
                                    if total <= 0 {
                                        remainingFraction = 0.0
                                    } else {
                                        let rem = max(0.0, holdEndDev - deviceNow)
                                        remainingFraction = min(1.0, max(0.0, rem / total))
                                    }
                                } else if let sd = self.startDate, let holdEnd = note.holdEndTime {
                                    let now = Date().timeIntervalSince1970
                                    let holdStartWall = sd.timeIntervalSince1970 + note.time
                                    let holdEndWall = sd.timeIntervalSince1970 + holdEnd
                                    let total = holdEndWall - holdStartWall
                                    if total <= 0 {
                                        remainingFraction = 0.0
                                    } else {
                                        let rem = max(0.0, holdEndWall - now)
                                        remainingFraction = min(1.0, max(0.0, rem / total))
                                    }
                                } else {
                                    // タイミング情報がなければ full のままにする（外部キャンセルで消す想定）
                                    remainingFraction = 1.0
                                }

                                // UI 更新
                                self.activeNotes[idx3].holdTrim = remainingFraction

                                // 扇形が設定しきい値以下になったら "very thin" とみなし完了扱いにする
                                if remainingFraction <= self.holdFinishTrimThreshold {
                                    timer.cancel()
                                    self.holdTimers[newID] = nil

                                    // visual: 小さくフェードして削除（必要なら成功判定を入れる）
                                    withAnimation(.easeIn(duration: 0.12)) {
                                        self.activeNotes.removeAll { $0.id == newID }
                                    }
                                }
                            }

                            // store and start timer
                            self.holdTimers[newID] = timer
                            timer.resume()
                        }

                        // ③: アプローチ移動（従来どおり）
                        if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                            withAnimation(.linear(duration: approachDuration)) {
                                self.activeNotes[idx].position = target
                                self.activeNotes[idx].position2 = target
                            }
                        }
                    } else {
                        // 通常ノーツ
                        let new = ActiveNote(
                            id: newID,
                            sourceID: note.id,
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
                                self.consecutiveCombo = 0
                                self.missCount += 1
                                self.autoDeleteWorkItems[newID] = nil
                                self.showJudgement(text: "MISS", color: .red)
                            }
                        }
                    }

                    // store and schedule deleteWork relative to now (spawn moment)
                    self.autoDeleteWorkItems[newID] = deleteWork
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.lifeDuration, execute: deleteWork)
                } // end DispatchQueue.main.async
            } // end spawnWork
            // clear: hitTime に鮮明表示にする
            // --- clearWork: use sourceID match when available, fallback to time/position match ---
            let clearWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    // Try to find by sourceID first (if notesToPlay items had ids)
                    var foundIndex: Int? = nil

                    // note.id が非 optional (String) の場合は普通に代入して使う
                    let sheetNoteID = note.id
                    if !sheetNoteID.isEmpty {
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
                    // cancel all hold timers
                    self.holdTimers.values.forEach { $0.cancel() }
                    self.holdTimers.removeAll()
                    // --- 追加: 今回プレイの最大コンボを通算へ反映・履歴へ追加 ---
                    self.cumulativeCombo += self.maxCombo
                    self.consecutiveCombo += self.maxCombo
                    self.playMaxHistory.append(self.maxCombo)
                    // 永続化（任意）
                    UserDefaults.standard.set(self.cumulativeCombo, forKey: "cumulativeCombo")
                    UserDefaults.standard.set(self.playMaxHistory, forKey: "playMaxHistory")
                    UserDefaults.standard.set(self.consecutiveCombo, forKey: "consecutiveCombo")
                    
                    // その後に結果表示フラグを立てる
                    self.isShowingResults = true
                    // show results
                    self.isShowingResults = true
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
            judgementText = "PERFECT"; judgementColor = .green;
            score += 3
        } else if (dt >= -goodWindowBefore && dt < -perfectWindow) || (dt > perfectWindow && dt <= goodWindowAfter) {
            judgementText = "GOOD"; judgementColor = .blue;
            score += 2
        } else {
            judgementText = "OK"; judgementColor = .white;
            score += 1
        }

        // スコア/コンボ
        combo += 1
        if combo > maxCombo {
            maxCombo = combo
        }

        // カウント増加
        switch judgementText {
        case "PERFECT":
            perfectCount += 1
        case "GOOD":
            goodCount += 1
        case "OK":
            okCount += 1
        default:
            break
        }

        // 最大コンボ更新
        if combo > maxCombo {
            maxCombo = combo
        }

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
// 上向き三角
struct TriangleUp: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// 下向き三角
struct TriangleDown: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
// 扇形 (0..1 の progress に応じて扇形を描画。0 => 無し, 1 => full circle)
struct Sector: Shape {
    var progress: Double // 0..1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2.0
        let startAngle = -Double.pi / 2.0 // 12時から時計回り
        let endAngle = startAngle + progress * 2.0 * Double.pi

        p.move(to: center)
        p.addArc(center: center,
                 radius: radius,
                 startAngle: Angle(radians: startAngle),
                 endAngle: Angle(radians: endAngle),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

// Hold 表示コンポーネント
struct HoldView: View {
    // fillScale: 0..1 (内側実円の拡大)
    // trimProgress: 0..1 (ホールド残り割合: 1.0=満杯, 0.0=消滅)
    let size: CGFloat
    let fillScale: Double
    let trimProgress: Double
    let ringColor: Color
    let fillColor: Color
    var body: some View {
        ZStack {
            // 外周リング（中空の円周）
            Circle()
                .stroke(ringColor, lineWidth: max(3, size * 0.06))
                .frame(width: size, height: size)

            // 内側の実円（拡大）を、扇形マスクで切り抜くことで「消える」表現にする
            Circle()
                .fill(fillColor)
                .frame(width: size * CGFloat(max(0.0, fillScale)), height: size * CGFloat(max(0.0, fillScale)))
                .opacity(fillScale > 0.001 ? 1.0 : 0.0)
                .mask(
                    // Sector は 0..1 の範囲を描く。trimProgress が 1 => 見える、0 => 見えない
                    Sector(progress: trimProgress)
                        .frame(width: size, height: size)
                )
        }
        .frame(width: size, height: size)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
