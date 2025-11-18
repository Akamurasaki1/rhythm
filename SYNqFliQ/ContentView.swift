//
//  ContentView.swift
//  rhythm
//
//  Created by Karen Naito on 2025/11/15.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import AVKit

// Models.swift の Note / Sheet / SheetNote を使う前提
// （このファイルはあなたが渡した ContentView を最小修正したもの）
/// メイン画面：ContentView 相当（ファイル名が MainView.swift ですが中身は ContentView）
struct ContentView: View {
    // ActiveNote: 表示用インスタンス（spawn 時に id が決まる）
    // --- Replace ActiveNote definition with this ---
    // Replace the existing ActiveNote definition in ContentView with this version.
    // (Only the ActiveNote struct needs replacing — paste this over your current private struct ActiveNote.)
    // Replace / extend your ActiveNote with these additional fields:
    private struct ActiveNote: Identifiable {
        let id: UUID
        let sourceID: String?
        let angleDegrees: Double
        var position: CGPoint
        let targetPosition: CGPoint
        let hitTime: Double
        let spawnTime: Double
        var isClear: Bool

        // type flags
        var isTap: Bool = false
        var isHold: Bool = false
        var position2: CGPoint? = nil

        // hold fields (existing)
        var holdEndTime: Double? = nil
        var holdStarted: Bool = false
        var holdFillScale: Double = 0.0
        var holdTrim: Double = 1.0
        var holdStartDeviceTime: TimeInterval? = nil
        var holdStartWallTime: TimeInterval? = nil
        var holdTotalSeconds: Double = 0.0
        var holdRemainingSeconds: Double = 0.0
        var holdPressedByUser: Bool = false
        var holdWasReleased: Bool = false
        var holdPressDeviceTime: TimeInterval? = nil
        var holdLastTickDeviceTime: TimeInterval? = nil
        var holdCompletedWhileStopped: Bool = false
        var holdReachedEnd: Bool = false

        // NEW: approach / spawn-driven movement fields (timer-driven)
        var startPosition: CGPoint = .zero           // where it starts moving from
        var approachStartDeviceTime: TimeInterval? = nil // device time when movement begins
        var approachStartWallTime: TimeInterval? = nil   // fallback wall clock
        var approachEndDeviceTime: TimeInterval? = nil   // device time when movement ends (target reached)
        var approachEndWallTime: TimeInterval? = nil     // fallback
        var approachDuration: Double = 0.0               // seconds
    }
    // 組み込み sample データは空にする（別プロジェクトでは「新たに入れたデータのみ」を扱う）
    private let sampleDataSets: [[Note]] = []
    // game loop timer to update positions and hold progress (single timer)

    @State private var gameLoopTimer: DispatchSourceTimer? = nil
    // desired update interval (seconds)
    private let gameLoopInterval: Double = 1.0 / 60.0 // 60Hz
    // Combine 表示数（組み込みサンプル + bundled-sheets 内の譜面）
    private var sampleCount: Int { sampleDataSets.count + bundledSheets.count }
    
    // Background media
    @State private var backgroundImage: UIImage? = nil
    @State private var backgroundPlayer: AVQueuePlayer? = nil      // use AVQueuePlayer for looping support
    // Audio engine based playback
    @State private var audioEngine: AVAudioEngine? = nil
    @State private var playerNode: AVAudioPlayerNode? = nil
    @State private var audioFile: AVAudioFile? = nil

    // store when we scheduled (AVAudioTime)
    @State private var audioStartHostTime: UInt64? = nil // hostTime used when scheduling
    @State private var audioSampleRate: Double = 44100.0 // will be updated from file
    @State private var backgroundPlayerLooper: AVPlayerLooper? = nil
    @State private var backgroundIsVideo: Bool = false
    @State private var backgroundFilename: String? = nil
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
    // --- 追加: stop（pause）モードフラグ ---
    @State private var isStopped: Bool = false
    // Pause/Resume のために追加する状態
    @State private var scheduledSpawnTimes: [UUID: TimeInterval] = [:]            // noteID -> executeTime (device or wall)
    @State private var scheduledClearTimes: [UUID: TimeInterval] = [:]
    @State private var scheduledSpawnWorkItemsByNote: [UUID: DispatchWorkItem] = [:]
    @State private var scheduledClearWorkItemsByNote: [UUID: DispatchWorkItem] = [:]
    // データ再作成のために spawn 時に必要な情報を保存
    @State private var scheduledNoteInfos: [UUID: (sheetNote: SheetNote, target: CGPoint, approachDuration: Double, spawnTime: Double, clearTime: Double)] = [:]
    // pause 時に残り時間を保存する
    @State private var pausedRemainingDelays: [UUID: (spawn: TimeInterval?, clear: TimeInterval?)] = [:]
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
    
    // new: how long inner white fill takes as fraction of approachDuration
    @State private var holdFillDurationFraction: Double = 1.0
    // threshold for considering "very thin" (finish) of holdTrim (0..1)
    @State private var holdFinishTrimThreshold: Double = 0.02
    // release judgement windows (seconds before hold end)
    @State private var holdReleaseGoodWindow: Double = 0.25   // if released within this many seconds before end -> GOOD
    @State private var holdReleaseOkWindow: Double = 1.0      // if released within this many seconds before end -> OK (else MISS)
    private func prepareAudioEngineIfNeeded(url: URL) {
        // teardown existing if any
        if let engine = audioEngine {
            engine.stop()
            audioEngine = nil
            playerNode = nil
            audioFile = nil
        }

        do {
            let file = try AVAudioFile(forReading: url)
            self.audioFile = file

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)

            // connect player to main mixer
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

            try engine.start()
            self.audioEngine = engine
            self.playerNode = player
            self.audioSampleRate = file.processingFormat.sampleRate

            print("DBG: prepared audioEngine for \(url.lastPathComponent), sampleRate=\(audioSampleRate)")
        } catch {
            print("DBG: prepareAudioEngine failed: \(error)")
        }
    }
    // schedule audio to play at a hostTime (optionally immediate)
    private func scheduleAudioStart(atHostTime hostTime: UInt64? = nil) {
        guard let engine = audioEngine, let player = playerNode, let file = audioFile else { return }

        // stop if already playing
        if player.isPlaying {
            player.stop()
        }

        // create a host-time based AVAudioTime if requested
        var startTime: AVAudioTime? = nil
        if let ht = hostTime {
            // create AVAudioTime referencing hostTime, sampleTime derived is optional
            startTime = AVAudioTime(hostTime: ht)
        }

        // schedule file: completion handler optional
        player.scheduleFile(file, at: startTime, completionHandler: {
            DispatchQueue.main.async {
                print("DBG: audio finished")
                // handle end-of-song logic
            }
        })

        // store hostTime used
        if let st = startTime {
            audioStartHostTime = st.hostTime
        } else {
            // if start immediately, get current host time
            audioStartHostTime = mach_absolute_time()
        }

        player.play()
        print("DBG: scheduled audio play at hostTime \(String(describing: audioStartHostTime))")
    }
    
    // 判定窓 (initial press judgement, reused)
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
    // new: track whether finger is currently down and its location (for hold interactions)
    @State private var isFingerDown: Bool = false
    @State private var fingerLocation: CGPoint? = nil
    // タップ判定用に狭めのヒット半径（中央をピンポイントで狙わせる）
    private let tapHitRadius: CGFloat = 10.0
    // タップを受け付け始める最小時間（秒）: 到達(=hitTime) の何秒前からタップ受付するか
    private let tapEarliestBeforeHit: Double = 0.3
    // タップ三角の表示サイズ（既存の HoldView/Triangle の frame に合わせる）
    private let tapTriangleWidth: CGFloat = 44.0
    private let tapTriangleHeight: CGFloat = 22.0
    // ContentView に追加する @State多点タップ
    @State private var touchToNote: [Int: UUID] = [:] // touch id -> activeNote id
    private func prepareBackgroundIfNeeded(named filename: String?) {
        // first tear down any existing background
        if let player = backgroundPlayer {
            player.pause()
            backgroundPlayerLooper = nil
            backgroundPlayer = nil
        }
        backgroundImage = nil
        backgroundIsVideo = false
        backgroundFilename = nil

        guard let filename = filename, !filename.isEmpty else { return }

        guard let url = bundleURLForMedia(named: filename) else {
            print("DBG: prepareBackgroundIfNeeded: media not found for \(filename)")
            return
        }

        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "heif"].contains(ext) {
            // load image
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                backgroundImage = img
                backgroundIsVideo = false
                backgroundFilename = filename
                print("DBG: background image prepared: \(filename)")
            } else {
                print("DBG: background image load failed for \(url)")
            }
        } else if ["mp4", "mov", "m4v"].contains(ext) {
            // prepare video with AVQueuePlayer + AVPlayerLooper for optional loop
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer(items: [item])
            // optional: loop
            let looper = AVPlayerLooper(player: queue, templateItem: item)
            queue.isMuted = true // keep video muted by default; unmute if desired
            queue.actionAtItemEnd = .none
            backgroundPlayerLooper = looper
            backgroundPlayer = queue
            backgroundIsVideo = true
            backgroundFilename = filename
            print("DBG: background video prepared: \(filename)")
        } else {
            print("DBG: unknown background extension \(ext) for \(filename)")
        }
    }
    // Helper: find media file in bundle or Documents (images or videos)
    private func bundleURLForMedia(named mediaFilename: String?) -> URL? {
        guard let mediaFilename = mediaFilename, !mediaFilename.isEmpty else { return nil }
        let ext = (mediaFilename as NSString).pathExtension
        let name = (mediaFilename as NSString).deletingPathExtension

        // try subdirectories similar to audio
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext, subdirectory: "bundled-resources") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext) {
            return url
        }

        // fallback: check Documents folder (imported media)
        if let c = try? FileManager.default.contentsOfDirectory(at: SheetFileManager.documentsURL, includingPropertiesForKeys: nil, options: []) {
            if let found = c.first(where: { $0.deletingPathExtension().lastPathComponent == name && $0.pathExtension.lowercased() == ext.lowercased() }) {
                return found
            }
            if let found = c.first(where: { $0.deletingPathExtension().lastPathComponent == name }) {
                return found
            }
        }

        return nil
    }
    // find nearest note id helper (ContentView 内に追加)
    private func findNearestNoteId(to loc: CGPoint, within radius: CGFloat = 110.0) -> UUID? {
        var nearest: UUID? = nil
        var bestDist = CGFloat.greatestFiniteMagnitude
        for n in activeNotes {
            let d = hypot(n.targetPosition.x - loc.x, n.targetPosition.y - loc.y)
            if d < bestDist && d <= radius {
                bestDist = d
                nearest = n.id
            }
        }
        return nearest
    }
    private func startGameLoopIfNeeded() {
        // if already running, keep it
        if gameLoopTimer != nil { return }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(Int(gameLoopInterval * 1000.0)))
        // NOTE: remove `[weak self]` because ContentView is a struct
        timer.setEventHandler {
            // We are already on the main queue, but to be explicit:
            self.gameLoopTick()
        }
        gameLoopTimer = timer
        timer.resume()
        print("DBG: gameLoop started")
    }
    private func gameLoopTick() {
        // current "device" time if audio is present, else wall time
        let nowDev: TimeInterval
        if let player = audioPlayer {
            nowDev = player.deviceCurrentTime
        } else {
            nowDev = Date().timeIntervalSince1970
        }

        // iterate over notes and update positions / hold progress
        var idsToRemove: [UUID] = []

        // For delta computations per-note, compute per-note lastTick when needed
        for i in (0..<activeNotes.count).reversed() {
            var note = activeNotes[i] // copy
            // --- Movement update (approach) ---
            // Determine approach start/end time (use device if available else wall)
            let approachStart = note.approachStartDeviceTime ?? note.approachStartWallTime ?? (nowDev - note.approachDuration)
            let approachEnd = note.approachEndDeviceTime ?? note.approachEndWallTime ?? (approachStart + note.approachDuration)

            if nowDev <= approachStart {
                // not started moving yet: keep startPosition
                note.position = note.startPosition
                if note.isTap { note.position2 = note.startPosition }
            } else if nowDev >= approachEnd {
                // reached target
                note.position = note.targetPosition
                if note.isTap { note.position2 = note.targetPosition }
            } else {
                // in-flight: compute fraction and update position linearly
                let t = max(0.0, min(1.0, (nowDev - approachStart) / max(0.00001, note.approachDuration)))
                // linear interpolation
                let sx = note.startPosition.x
                let sy = note.startPosition.y
                let tx = note.targetPosition.x
                let ty = note.targetPosition.y
                let nx = sx + (tx - sx) * CGFloat(t)
                let ny = sy + (ty - sy) * CGFloat(t)
                note.position = CGPoint(x: nx, y: ny)
                if note.isTap { note.position2 = note.position }
            }

            // --- Hold fill / progress update (if hold) ---
            if note.isHold {
                // compute fill duration and fill end time
                let fillDuration = max(0.0, note.approachDuration * holdFillDurationFraction)
                let fillEndTime = (note.approachStartDeviceTime != nil) ? (note.approachStartDeviceTime! + fillDuration) : (note.approachStartWallTime! + fillDuration)

                // update holdFillScale (0->1 during fill)
                if nowDev < fillEndTime {
                    let fillT = (nowDev - (note.approachStartDeviceTime ?? note.approachStartWallTime ?? nowDev)) / max(0.00001, fillDuration)
                    note.holdFillScale = max(0.0, min(1.0, fillT))
                } else {
                    note.holdFillScale = 1.0
                    // mark holdStarted (once)
                    if !note.holdStarted {
                        note.holdStarted = true
                        // record start times if not recorded
                        if self.audioPlayer != nil {
                            note.holdStartDeviceTime = self.audioPlayer?.deviceCurrentTime
                            note.holdLastTickDeviceTime = note.holdStartDeviceTime
                        } else {
                            note.holdStartWallTime = Date().timeIntervalSince1970
                            note.holdLastTickDeviceTime = note.holdStartWallTime
                        }
                        // If user currently has finger down near this note, mark pressed
                        if self.isFingerDown, let finger = self.fingerLocation {
                            let d = hypot(note.targetPosition.x - finger.x, note.targetPosition.y - finger.y)
                            if d <= self.hitRadius && !note.holdPressedByUser && !note.holdWasReleased {
                                note.holdPressedByUser = true
                                note.holdPressDeviceTime = note.holdLastTickDeviceTime
                            }
                        }
                    }
                }

                // update hold remaining only when pressing
                if note.holdPressedByUser && !note.holdWasReleased {
                    // delta since last tick
                    let lastTick = note.holdLastTickDeviceTime ?? nowDev
                    let delta = max(0.0, nowDev - lastTick)
                    note.holdLastTickDeviceTime = nowDev
                    note.holdRemainingSeconds = max(0.0, note.holdRemainingSeconds - delta)
                    // update trim
                    let total = max(0.0001, note.holdTotalSeconds)
                    note.holdTrim = min(1.0, max(0.0, note.holdRemainingSeconds / total))

                    // if fully held -> immediate success (user need not release)
                    if note.holdRemainingSeconds <= 0.0001 {
                        // award PERFECT and schedule removal
                        self.perfectCount += 1
                        self.score += 3
                        self.combo += 1
                        if self.combo > self.maxCombo { self.maxCombo = self.combo }
                        self.showJudgement(text: "PERFECT", color: .green)
                        idsToRemove.append(note.id)
                    }
                } else {
                    // not pressing: if holdEndTime passed and too long since, mark miss
                    // compute holdEnd in device/wall time
                    var holdEndDev: TimeInterval? = nil
                    if let hed = note.holdEndTime {
                        if let startDev = self.audioStartDeviceTime, self.audioPlayer != nil {
                            holdEndDev = startDev + hed
                        } else if let sd = self.startDate {
                            holdEndDev = sd.timeIntervalSince1970 + hed
                        } else if let hs = note.holdStartDeviceTime {
                            holdEndDev = hs + note.holdTotalSeconds
                        } else if let hs = note.holdStartWallTime {
                            holdEndDev = hs + note.holdTotalSeconds
                        }
                    } else {
                        // fallback: computed from holdStart + total
                        if let hs = note.holdStartDeviceTime { holdEndDev = hs + note.holdTotalSeconds }
                        else if let hs = note.holdStartWallTime { holdEndDev = hs + note.holdTotalSeconds }
                    }
                    if let hed = holdEndDev {
                        if nowDev - hed > 0.5 && !note.holdPressedByUser {
                            // miss
                            self.missCount += 1
                            self.combo = 0
                            self.consecutiveCombo = 0
                            self.showJudgement(text: "MISS", color: .red)
                            idsToRemove.append(note.id)
                        }
                    }
                }
            } // end hold handling

            // Write back modified note
            activeNotes[i] = note
        } // end for

        // remove finished notes (with a short animation)
        if !idsToRemove.isEmpty {
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.12)) {
                    for id in idsToRemove {
                        self.activeNotes.removeAll { $0.id == id }
                        // clean any timers/auto delete etc.
                        if let w = self.autoDeleteWorkItems[id] { w.cancel(); self.autoDeleteWorkItems[id] = nil }
                        if let t = self.holdTimers[id] { t.cancel(); self.holdTimers[id] = nil }
                    }
                }
            }
        }
    }

    private func stopGameLoopIfNeeded() {
        if let t = gameLoopTimer {
            t.cancel()
            gameLoopTimer = nil
            print("DBG: gameLoop stopped")
        }
    }
    // hold 用進捗更新タイマーを保持（DispatchSourceTimer）
    @State private var holdTimers: [UUID: DispatchSourceTimer] = [:]
    // 長押し閾値（秒）
    private let longPressThreshold: TimeInterval = 0.35
    
    // Helper: convert current touch time to device time if audio available, else wall time
    private func currentDeviceTime() -> TimeInterval {
        if let player = audioPlayer {
            return player.deviceCurrentTime
        } else {
            return Date().timeIntervalSince1970
        }
    }
    
    private func handlePotentialLongPressStart(at location: CGPoint) {
        // stub for future
    }

    private func handlePotentialLongPressEnd(at location: CGPoint, duration: TimeInterval) {
        // stub for future
    }
    
    // Called when a finger first touches (begin): will attempt to register initial hold press for any hold note that is in holdStarted state.
    // Replace the existing handleHoldTouchBegan with this version
    private func handleHoldTouchBegan(at location: CGPoint) {
        guard !isStopped else { return }
        isFingerDown = true
        fingerLocation = location
        let nowDevice = currentDeviceTime()

        // find nearest hold note that is not released and not already pressed
        var closestIdx: Int? = nil
        var closestDist = CGFloat.greatestFiniteMagnitude
        for (i, n) in activeNotes.enumerated() {
            guard n.isHold else { continue }
            guard n.holdWasReleased == false else { continue } // cannot re-press after release
            guard n.holdPressedByUser == false else { continue } // already pressed
            let d = hypot(n.targetPosition.x - location.x, n.targetPosition.y - location.y)
            if d < closestDist && d <= hitRadius {
                closestDist = d
                closestIdx = i
            }
        }
        guard let idx = closestIdx else { return }

        // If hold has not started (fill incomplete), just mark pressed so timer will decrement once started.
        if !activeNotes[idx].holdStarted {
            activeNotes[idx].holdPressedByUser = true
            activeNotes[idx].holdPressDeviceTime = nowDevice
            activeNotes[idx].holdLastTickDeviceTime = nowDevice
            // Do not perform initial timing judgement here because hold start time hasn't been set.
            // optional visual cue:
            // self.showJudgement(text: "OK", color: .white)
            return
        }

        // If holdStarted == true, perform initial press timing judgement as before
        var startTimeRef: TimeInterval?
        if let t = activeNotes[idx].holdStartDeviceTime {
            startTimeRef = t
        } else if let t = activeNotes[idx].holdStartWallTime {
            startTimeRef = t
        } else {
            if let player = audioPlayer, let startDev = audioStartDeviceTime {
                startTimeRef = startDev + activeNotes[idx].hitTime
            } else if let sd = startDate {
                startTimeRef = sd.timeIntervalSince1970 + activeNotes[idx].hitTime
            }
        }
        guard let holdStartRef = startTimeRef else {
            // fallback: mark pressed
            activeNotes[idx].holdPressedByUser = true
            activeNotes[idx].holdPressDeviceTime = nowDevice
            activeNotes[idx].holdLastTickDeviceTime = nowDevice
            return
        }

        let dt = nowDevice - holdStartRef
        var judgementText = "OK"
        var judgementColor: Color = .white
        if abs(dt) <= perfectWindow {
            judgementText = "PERFECT"; judgementColor = .green
            score += 3
        } else if (dt >= -goodWindowBefore && dt < -perfectWindow) || (dt > perfectWindow && dt <= goodWindowAfter) {
            judgementText = "GOOD"; judgementColor = .blue
            score += 2
        } else {
            let tooLateEarly = (dt < -goodWindowBefore) || (dt > goodWindowAfter)
            if tooLateEarly {
                judgementText = "MISS"; judgementColor = .red
                missCount += 1
                activeNotes[idx].holdWasReleased = true
                withAnimation(.easeIn(duration: 0.12)) {
                    self.activeNotes.removeAll { $0.id == activeNotes[idx].id }
                }
                showJudgement(text: judgementText, color: judgementColor)
                return
            } else {
                judgementText = "OK"; judgementColor = .white
                score += 1
            }
        }

        // scoring & combo for initial press
        combo += 1
        if combo > maxCombo { maxCombo = combo }
        switch judgementText {
        case "PERFECT": perfectCount += 1
        case "GOOD": goodCount += 1
        case "OK": okCount += 1
        default: break
        }
        showJudgement(text: judgementText, color: judgementColor)

        // mark as pressed and store press time
        activeNotes[idx].holdPressedByUser = true
        activeNotes[idx].holdPressDeviceTime = nowDevice
        activeNotes[idx].holdLastTickDeviceTime = nowDevice
    }
    
    // Called when finger lifts: finalize hold release judgement for the note the // Replace existing handleHoldTouchEnded(at:) with this implementation.
    private func handleHoldTouchEnded(at location: CGPoint) {
        // 操作無効中は無視
        guard !isStopped else { return }

        isFingerDown = false
        fingerLocation = nil
        let nowDevice = currentDeviceTime()

        // find nearest hold note that user had pressed (holdPressedByUser == true and not yet released)
        var pressedIdx: Int? = nil
        var pressedDist = CGFloat.greatestFiniteMagnitude
        for (i, n) in activeNotes.enumerated() {
            guard n.isHold else { continue }
            guard n.holdPressedByUser == true else { continue }
            guard n.holdWasReleased == false else { continue }
            let d = hypot(n.targetPosition.x - location.x, n.targetPosition.y - location.y)
            if d < pressedDist {
                pressedDist = d
                pressedIdx = i
            }
        }
        guard let idx = pressedIdx else { return }
        let note = activeNotes[idx]

        // mark released locally first to prevent timer racing
        activeNotes[idx].holdWasReleased = true
        activeNotes[idx].holdPressedByUser = false
        activeNotes[idx].holdLastTickDeviceTime = nil

        // determine holdEnd reference (device or wall)
        var holdEndRef: TimeInterval?
        if let player = audioPlayer, let startDev = audioStartDeviceTime, let hed = note.holdEndTime {
            holdEndRef = startDev + hed
        } else if let sd = startDate, let hed = note.holdEndTime {
            holdEndRef = sd.timeIntervalSince1970 + hed
        } else {
            // fallback: use holdStart + total duration if available
            if let start = note.holdStartDeviceTime {
                holdEndRef = start + note.holdTotalSeconds
            } else if let start = note.holdStartWallTime {
                holdEndRef = start + note.holdTotalSeconds
            }
        }

        // If we cannot compute hold end, fallback to a simple OK judgement
        guard let holdEnd = holdEndRef else {
            showJudgement(text: "OK", color: .white)
            return
        }

        // deltaToEnd: positive => released BEFORE end (early); negative/zero => released at/after end
        let deltaToEnd = holdEnd - nowDevice

        var releaseJudgement = "OK"
        var releaseColor: Color = .white
        // Map early-release distance to judgement:
        // - held through end (deltaToEnd <= 0) => PERFECT
        // - released slightly early (<= holdReleaseGoodWindow) => GOOD
        // - released moderately early (<= holdReleaseOkWindow) => OK
        // - released too early (> holdReleaseOkWindow) => MISS
        if deltaToEnd <= 0.0 {
            releaseJudgement = "PERFECT"
            releaseColor = .green
            score += 3
            perfectCount += 1
        } else if deltaToEnd <= holdReleaseGoodWindow {
            releaseJudgement = "GOOD"
            releaseColor = .blue
            score += 2
            goodCount += 1
        } else if deltaToEnd <= holdReleaseOkWindow {
            releaseJudgement = "OK"
            releaseColor = .white
            score += 1
            okCount += 1
        } else {
            releaseJudgement = "MISS"
            releaseColor = .red
            missCount += 1
            // reset combos on miss
            combo = 0
            consecutiveCombo = 0
        }

        // Update combo / maxCombo for non-miss results.
        if releaseJudgement != "MISS" {
            combo += 1
            if combo > maxCombo { maxCombo = combo }
        }

        showJudgement(text: releaseJudgement, color: releaseColor)

        // Remove visual note and cancel timer if appropriate.
        // If the note's hold was already completed by the timer (and removed), activeNotes might not contain it.
        // We already have 'note' captured from before; use its id for cleanup.
        let noteID = note.id

        // Cancel and remove any hold timer for this note
        if let timer = holdTimers[noteID] {
            timer.cancel()
            holdTimers[noteID] = nil
        }
        // Remove visual after short fade (for MISS/OK/GOOD/PERFECT on release)
        withAnimation(.easeIn(duration: 0.12)) {
            self.activeNotes.removeAll { $0.id == noteID }
        }
    }
    
    private func handleTap(at location: CGPoint, in _unused: CGPoint) {
        guard !isStopped else { return }

        // 現在経過時間（audio があれば deviceCurrentTime ベース、それ以外は wall time）
        var elapsed: TimeInterval = 0.0
        if let player = audioPlayer, let startDev = audioStartDeviceTime {
            elapsed = player.deviceCurrentTime - startDev
        } else if let sd = startDate {
            elapsed = Date().timeIntervalSince(sd)
        }

        // 候補ノートを収集（空間判定＋時間フィルタ）
        var candidateIndices: [Int] = []
        for (i, a) in activeNotes.enumerated() {
            guard a.isTap else { continue }

            // 時間フィルタ: 到達(hitTime) の tapEarliestBeforeHit 秒より前なら無効
            let earliestAccept = a.hitTime - tapEarliestBeforeHit
            if elapsed < earliestAccept {
                // 早すぎるタップは受け付けない
                continue
            }

            // 位置による候補判定（矩形 + 中心半径の両方を考慮）
            let triangleH = tapTriangleHeight
            let halfSeparation = triangleH / 2.0
            let finalTop = CGPoint(x: a.targetPosition.x, y: a.targetPosition.y - halfSeparation)
            let finalBottom = CGPoint(x: a.targetPosition.x, y: a.targetPosition.y + halfSeparation)

            let topRect = CGRect(x: finalTop.x - tapTriangleWidth/2.0,
                                 y: finalTop.y - triangleH/2.0,
                                 width: tapTriangleWidth,
                                 height: triangleH)
            let bottomRect = CGRect(x: finalBottom.x - tapTriangleWidth/2.0,
                                    y: finalBottom.y - triangleH/2.0,
                                    width: tapTriangleWidth,
                                    height: triangleH)

            if topRect.contains(location) || bottomRect.contains(location) {
                candidateIndices.append(i)
                continue
            }

            // fallback: small center radius
            let d = hypot(a.targetPosition.x - location.x, a.targetPosition.y - location.y)
            if d <= tapHitRadius {
                candidateIndices.append(i)
                continue
            }
        }

        // 候補無しなら何もしない
        guard !candidateIndices.isEmpty else { return }

        // 候補が複数なら timing（elapsed と note.hitTime の差が小さいもの）で最良を選ぶ
        var bestIdx: Int? = nil
        var bestTimeDiff = Double.greatestFiniteMagnitude
        for idx in candidateIndices {
            let note = activeNotes[idx]
            let dt = abs(elapsed - note.hitTime)
            if dt < bestTimeDiff {
                bestTimeDiff = dt
                bestIdx = idx
            }
        }
        guard let idx = bestIdx else { return }

        // 判定（従来の perfect/good/ok ロジックをそのまま適用）
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

        // スコア/コンボ更新
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
    
    // Replace / Add this inside ContentView
    private func pausePlayback() {
        stopGameLoopIfNeeded()
        // allow calling even if isStopped was already set; only require isPlaying
        guard isPlaying else {
            print("DBG: pausePlayback called but isPlaying=\(isPlaying) -> ignore")
            return
        }
        // mark stopped early so other logic sees it
        isStopped = true

        // pause audio if playing
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
        }
        // pause background video if playing
        if backgroundIsVideo {
            backgroundPlayer?.pause()
        }

        // 1) Cancel per-note scheduled DispatchWorkItems that we stored for spawn/clear
        if !scheduledSpawnWorkItemsByNote.isEmpty {
            for (id, work) in scheduledSpawnWorkItemsByNote {
                work.cancel()
                print("DBG: cancelled scheduledSpawnWork for note \(id)")
            }
            scheduledSpawnWorkItemsByNote.removeAll()
        }
        if !scheduledClearWorkItemsByNote.isEmpty {
            for (id, work) in scheduledClearWorkItemsByNote {
                work.cancel()
                print("DBG: cancelled scheduledClearWork for note \(id)")
            }
            scheduledClearWorkItemsByNote.removeAll()
        }

        // 2) Cancel general scheduledWorkItems array (if used)
        if !scheduledWorkItems.isEmpty {
            for w in scheduledWorkItems {
                w.cancel()
            }
            scheduledWorkItems.removeAll()
            print("DBG: cancelled scheduledWorkItems array")
        }

        // 3) Cancel auto-delete work items (non-hold auto removals)
        if !autoDeleteWorkItems.isEmpty {
            for (id, w) in autoDeleteWorkItems {
                w.cancel()
                print("DBG: cancelled autoDeleteWork for note \(id)")
            }
            autoDeleteWorkItems.removeAll()
        }

        // 4) Cancel all hold timers (DispatchSource timers)
        if !holdTimers.isEmpty {
            for (id, t) in holdTimers {
                t.cancel()
                print("DBG: cancelled holdTimer for note \(id)")
            }
            holdTimers.removeAll()
        }

        // 5) Save remaining delays for resume (if you implement resume later)
        pausedRemainingDelays.removeAll()
        let now = currentDeviceTime()
        for (id, exec) in scheduledSpawnTimes {
            let remaining = max(0.0, exec - now)
            var entry = pausedRemainingDelays[id] ?? (nil, nil)
            entry.spawn = remaining
            pausedRemainingDelays[id] = entry
            print("DBG: pause: spawn remaining for \(id) = \(remaining)")
        }
        for (id, exec) in scheduledClearTimes {
            let remaining = max(0.0, exec - now)
            var entry = pausedRemainingDelays[id] ?? (nil, nil)
            entry.clear = remaining
            pausedRemainingDelays[id] = entry
            print("DBG: pause: clear remaining for \(id) = \(remaining)")
        }
        scheduledSpawnTimes.removeAll()
        scheduledClearTimes.removeAll()

        // 6) Try to break ongoing implicit animations (best-effort freeze)
        withTransaction(Transaction(animation: nil)) {
            for i in 0..<activeNotes.count {
                activeNotes[i].position = activeNotes[i].position
                if activeNotes[i].position2 != nil {
                    activeNotes[i].position2 = activeNotes[i].position2
                }
            }
        }

        print("DBG: pausePlayback completed: cancelled scheduled items, timers, autoDelete. activeNotes.count=\(activeNotes.count)")
    }
    // Helper: this encapsulates the spawn behavior that was originally inside spawnWork's DispatchQueue.main.async block.
    // Call performSpawnNow(for: noteID, with: info)
    private func performSpawnNow(for noteID: UUID, with info: (sheetNote: SheetNote, target: CGPoint, approachDuration: Double, spawnTime: Double, clearTime: Double)) {
        // This should replicate the same logic that used to run in spawnWork:
        // - Create ActiveNote (tap/hold/normal)
        // - Append to activeNotes
        // - Start hold fill animation if hold note (set holdFillScale via withAnimation)
        // - Create and start hold timer if needed (same code as in startPlayback spawn branch)
        // For brevity here I point to where to copy the spawn-handling code from startPlayback:
        // Copy the block that created ActiveNote and animated its .position / .position2, and the whole DispatchQueue.main.asyncAfter(fillDuration) logic for holds.
        // Replace references to 'note' with info.sheetNote, 'target' with info.target, 'approachDuration' with info.approachDuration, and 'newID' with noteID.

        // Example minimal stub (you must copy the detailed spawn code here):
        guard scheduledNoteInfos[noteID] != nil else { return }
        // NOTE: Copy-paste the spawn branch from startPlayback for tap/hold/normal here,
        // using these param values. Keeping code DRY by extracting is recommended.
    }
    private func performClearNow(for noteID: UUID, with info: (sheetNote: SheetNote, target: CGPoint, approachDuration: Double, spawnTime: Double, clearTime: Double)) {
        // This should replicate the clearWork body: find corresponding ActiveNote by sourceID or hitTime+target,
        // and set .isClear = true with animation.
        // Copy the clearWork code from startPlayback, replacing 'note' with info.sheetNote and 'target' with info.target.
    }
    private func resumePlayback() {
        guard isPlaying && isStopped else { return }
        isStopped = false

        // resume audio
        if let player = audioPlayer {
            player.play()
        }
        // resume background video
        if backgroundIsVideo {
            backgroundPlayer?.play()
        }

        let now = currentDeviceTime()

        // Reschedule spawn/clear for paused notes using pausedRemainingDelays and scheduledNoteInfos
        for (noteID, delays) in pausedRemainingDelays {
            guard let info = scheduledNoteInfos[noteID] else {
                // no metadata -> skip
                continue
            }

            // recreate spawnWork & clearWork closures using the same pattern as in startPlayback:
            // We need to reconstruct DispatchWorkItems that call exactly the same spawn/clear body.
            // For spawn, create a new DispatchWorkItem that calls the same spawn body by invoking a helper function.
            let spawnWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    // call the same spawn behavior: create ActiveNote etc.
                    // We reuse the same creation logic as originally in startPlayback.
                    // For simplicity, invoke a helper that performs the spawn now:
                    self.performSpawnNow(for: noteID, with: info)
                }
            }
            scheduledSpawnWorkItemsByNote[noteID] = spawnWork

            if let spawnRem = delays.spawn {
                // schedule with remaining time
                DispatchQueue.main.asyncAfter(deadline: .now() + spawnRem, execute: spawnWork)
                // Update scheduledSpawnTimes to new absolute execute time (device/wall)
                scheduledSpawnTimes[noteID] = now + spawnRem
            } else {
                // if no spawn scheduled originally, do nothing
            }

            let clearWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    self.performClearNow(for: noteID, with: info)
                }
            }
            scheduledClearWorkItemsByNote[noteID] = clearWork

            if let clearRem = delays.clear {
                DispatchQueue.main.asyncAfter(deadline: .now() + clearRem, execute: clearWork)
                scheduledClearTimes[noteID] = now + clearRem
            }
        }

        // Clear pausedRemainingDelays after rescheduling
        pausedRemainingDelays.removeAll()

        // Recreate hold timers for active holds (their holdRemainingSeconds is stored in ActiveNote)
        for (idx, var a) in activeNotes.enumerated() {
            if a.isHold && !a.holdWasReleased {
                // if timer doesn't exist, create one
                if holdTimers[a.id] == nil {
                    let newID = a.id
                    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                    timer.schedule(deadline: .now(), repeating: .milliseconds(33))
                    timer.setEventHandler {
                        // similar per-tick behavior: decrement only while holdPressedByUser, finalize on completion
                        guard let idx2 = self.activeNotes.firstIndex(where: { $0.id == newID }) else {
                            timer.cancel()
                            self.holdTimers[newID] = nil
                            return
                        }
                        if self.activeNotes[idx2].holdWasReleased {
                            timer.cancel()
                            self.holdTimers[newID] = nil
                            return
                        }
                        let nowDev: TimeInterval = (self.audioPlayer != nil) ? (self.audioPlayer!.deviceCurrentTime) : Date().timeIntervalSince1970
                        let lastTick = self.activeNotes[idx2].holdLastTickDeviceTime ?? nowDev
                        let delta = max(0.0, nowDev - lastTick)
                        self.activeNotes[idx2].holdLastTickDeviceTime = nowDev

                        if self.activeNotes[idx2].holdPressedByUser {
                            let newRemaining = max(0.0, self.activeNotes[idx2].holdRemainingSeconds - delta)
                            self.activeNotes[idx2].holdRemainingSeconds = newRemaining
                            let total = max(0.0001, self.activeNotes[idx2].holdTotalSeconds)
                            self.activeNotes[idx2].holdTrim = min(1.0, max(0.0, newRemaining / total))

                            if newRemaining <= 0.0001 {
                                timer.cancel()
                                self.holdTimers[newID] = nil
                                if self.isStopped {
                                    self.activeNotes[idx2].holdRemainingSeconds = 0.0
                                    self.activeNotes[idx2].holdTrim = 0.0
                                    self.activeNotes[idx2].holdCompletedWhileStopped = true
                                    return
                                }
                                self.perfectCount += 1
                                self.score += 3
                                self.combo += 1
                                if self.combo > self.maxCombo { self.maxCombo = self.combo }
                                self.showJudgement(text: "PERFECT", color: .green)
                                withAnimation(.easeIn(duration: 0.12)) {
                                    self.activeNotes.removeAll { $0.id == newID }
                                }
                            }
                        } else {
                            // not pressing: check for missed hold end
                            var holdEndDev: TimeInterval? = nil
                            if let player = self.audioPlayer, let startDev = self.audioStartDeviceTime, let hed = self.activeNotes[idx2].holdEndTime {
                                holdEndDev = startDev + hed
                            } else if let sd = self.startDate, let hed = self.activeNotes[idx2].holdEndTime {
                                holdEndDev = sd.timeIntervalSince1970 + hed
                            } else if let start = self.activeNotes[idx2].holdStartDeviceTime {
                                holdEndDev = start + self.activeNotes[idx2].holdTotalSeconds
                            } else if let start = self.activeNotes[idx2].holdStartWallTime {
                                holdEndDev = start + self.activeNotes[idx2].holdTotalSeconds
                            }
                            if let hed = holdEndDev {
                                if nowDev - hed > 0.5 && !self.activeNotes[idx2].holdPressedByUser {
                                    if self.isStopped { return }
                                    self.missCount += 1
                                    self.combo = 0
                                    self.consecutiveCombo = 0
                                    self.showJudgement(text: "MISS", color: .red)
                                    timer.cancel()
                                    self.holdTimers[newID] = nil
                                    withAnimation(.easeIn(duration: 0.12)) {
                                        self.activeNotes.removeAll { $0.id == newID }
                                    }
                                }
                            }
                        }
                    }
                    self.holdTimers[newID] = timer
                    timer.resume()
                }
            }
        }
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
                // --- add inside ZStack, just above other overlays (below Color.black) ---
                // --- BACKGROUND (最下層) ---
                if let uiimg = backgroundImage {
                    Image(uiImage: uiimg)
                        .resizable()
                        .scaledToFill()                          // 画面いっぱいに拡大して切り取り
                        .frame(width: geo.size.width, height: geo.size.height) // レイアウトに影響させないため明示サイズを与える
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .zIndex(0)
                } else if backgroundIsVideo, let player = backgroundPlayer {
                    // 動画を取り扱うなら同じく geo.size を指定
                    VideoPlayer(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .zIndex(0)
                } else {
                    Color.black
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .zIndex(0)
                }
                // ZStack の最上部に追加（他のビューの上）
                TouchOverlay(
                    onBegan: { id, loc in
                        guard isPlaying && !isStopped else { return }
                        // SwiftUI と同じ座標系で来るはずです（親ビュー全体を覆う）
                        if let noteId = findNearestNoteId(to: loc) {
                            touchToNote[id] = noteId
                            // If assigned note is hold => begin hold press for that location
                            if let idx = activeNotes.firstIndex(where: { $0.id == noteId }), activeNotes[idx].isHold {
                                // store finger location
                                self.fingerLocation = loc
                                self.isFingerDown = true
                                // call hold began
                                handleHoldTouchBegan(at: loc)
                            } else {
                                // for taps you could record and handle onEnded
                            }
                        } else {
                            // fallback: do nothing
                        }
                    },
                    onMoved: { id, loc in
                        // update finger location for nearest assigned hold
                        self.fingerLocation = loc
                    },
                    onEnded: { id, loc in
                        guard isPlaying && !isStopped else { return }
                        if let assigned = touchToNote[id] {
                            // If it's a hold, end it
                            if let idx = activeNotes.firstIndex(where: { $0.id == assigned }), activeNotes[idx].isHold {
                                handleHoldTouchEnded(at: loc)
                            } else {
                                // handle tap/flick end if desired
                            }
                            touchToNote[id] = nil
                        } else {
                            // fallback: call general handlers
                            handleHoldTouchEnded(at: loc)
                        }
                        // reset finger states if no more touches
                        self.isFingerDown = false
                        self.fingerLocation = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(isPlaying && !isStopped)
                

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
                            
                            // Controls for hold tuning (for debugging / tuning)
                            VStack {
                                HStack {
                                    Text("Hold fill fraction: \(String(format: "%.2f", holdFillDurationFraction))")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                Slider(value: $holdFillDurationFraction, in: 0.2...1.8)
                                
                                HStack {
                                    Text("Hold finish trim threshold: \(String(format: "%.3f", holdFinishTrimThreshold))")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                Slider(value: $holdFinishTrimThreshold, in: 0.001...0.08)
                            }
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
                                 fillColor: a.holdPressedByUser ? Color.green.opacity(0.95) : Color.white.opacity(0.95))
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
                            if isPlaying && !isStopped {
                                // Pause
                                pausePlayback()
                            } else if isPlaying && isStopped {
                                // Resume
                                // Note: resumePlayback should clear isStopped internally
                                resumePlayback()
                                // resume audio if we paused earlier
                                if let player = audioPlayer {
                                    player.play()
                                }
                            } else {
                                // Start new play
                                if selectedSampleIndex >= sampleDataSets.count {
                                    let bundledIndex = selectedSampleIndex - sampleDataSets.count
                                    if bundledSheets.indices.contains(bundledIndex) {
                                        sheetNotesToPlay = bundledSheets[bundledIndex].sheet.notes
                                        notesToPlay = bundledSheets[bundledIndex].sheet.notes.asNotes()
                                    } else {
                                        sheetNotesToPlay = []
                                        notesToPlay = []
                                    }
                                } else {
                                    notesToPlay = []
                                    sheetNotesToPlay = []
                                }
                                startPlayback(in: UIScreen.main.bounds.size)
                            }
                        }) {
                            Text(isPlaying && !isStopped ? "Stop" : (isPlaying && isStopped ? "Resume" : "Start"))
                                .font(.headline)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background((isPlaying && !isStopped) ? Color.red : Color.green)
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

            // グローバルフリック検出 + touch begin/end handling for hold notes
            .contentShape(Rectangle())
            // --- 置換: .simultaneousGesture(...) 全体 ---
            // ここを既存の .simultaneousGesture(DragGesture(...).onChanged{...}.onEnded{...}) の箇所に置き換えてください。
            .simultaneousGesture(
                (isPlaying && !isStopped) ?
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

                            // call hold touch began (first down)
                            handleHoldTouchBegan(at: value.startLocation)
                        } else {
                            // while moving, update finger location (used if needed)
                            fingerLocation = value.location
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
                                handleTap(at: value.location, in: value.startLocation)
                            } else {
                                // treat as flick if long drag
                                handleGlobalFlick(dragValue: value, in: UIScreen.main.bounds.size)
                            }
                        }

                        // call hold touch ended (release)
                        handleHoldTouchEnded(at: value.location)

                        // reset touch state
                        touchStartTime = nil
                        touchStartLocation = nil
                        touchIsLongPress = false
                    }
                : nil
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
        print("DBG: startPlayback called isPlaying=\(isPlaying) isStopped=\(isStopped) selectedIndex=\(selectedSampleIndex)")
        print("DBG: startPlayback entered isPlaying=\(isPlaying) selectedIndex=\(selectedSampleIndex) sampleDataSetsCount=\(sampleDataSets.count) bundledSheetsCount=\(bundledSheets.count)")
        if selectedSampleIndex >= sampleDataSets.count {
            let bidx = selectedSampleIndex - sampleDataSets.count
            print("DBG: selected bundled index = \(bidx), bundled sheet filename = \(bundledSheets.indices.contains(bidx) ? bundledSheets[bidx].filename : "out-of-range")")
        }
        // 変更: startPlayback の先頭（isPlaying の guard の手前または直後）で集計リセットを追加
        // 既に startPlayback 先頭に DBG: log を入れている箇所の直後が良いです。
        // start of a new play: reset per-play stats
        // --- 置換: startPlayback の冒頭（既存の maxCombo = 0 / score = 0 ... の箇所をこれに置き換え） ---
        // 再生開始時の統計リセットは「停止（stop）からの再開」かどうかで制御する。
        // isStopped == true かつ activeNotes が残っている状態を「一時停止からの再開」とみなす。
        let isResume = self.isStopped && !self.activeNotes.isEmpty
        if !isResume {
            maxCombo = 0
            score = 0
            combo = 0
            perfectCount = 0
            goodCount = 0
            okCount = 0
            missCount = 0
            isShowingResults = false
        }
        // 再生開始するなら停止フラグをクリア（resume の場合は isStopped が true → false になる）
        self.isStopped = false

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
                // prepare background media if the sheet has a backgroundFilename field
                if let bgName = sheetForOffset?.backgroundFilename {
                    prepareBackgroundIfNeeded(named: bgName)
                    // start video playback immediately (approx synced to audio)
                    if backgroundIsVideo, let bp = backgroundPlayer {
                        // slight lead to reduce visual glitch (optional)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            bp.play()
                        }
                    }
                }
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
        stopGameLoopIfNeeded()
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
            // === Replace the spawnWork block with this corrected and interactive-hold version ===
            let newID = UUID()
            let spawnWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    // --- In startPlayback, inside spawnWork when creating new ActiveNote ---

                    // note はループ変数を使う（sheet ではない）
                    let isTapNote = (note.noteType == "tap")
                    let isHoldNote = (note.noteType == "hold")

                    if isTapNote {
                        // TAP ノートの spawn 作成（置き換え）
                        let triangleH = tapTriangleHeight // 22.0
                        let halfSeparation = triangleH / 2.0 // centers の上下差の半分（=11.0）
                        let finalTop = CGPoint(x: target.x, y: target.y - halfSeparation)
                        let finalBottom = CGPoint(x: target.x, y: target.y + halfSeparation)
                        let info = (sheetNote: note, target: target, approachDuration: approachDuration, spawnTime: spawnTime, clearTime: note.time)
                        scheduledNoteInfos[newID] = info
                        // start positions を「少し近い」位置に調整して浮かび上がる見た目に
                        let topStart = CGPoint(x: finalTop.x, y: finalTop.y - approachDistance * 0.5 - 20.0)
                        let bottomStart = CGPoint(x: finalBottom.x, y: finalBottom.y + approachDistance * 0.5 + 20.0)

                        // Create ActiveNote: targetPosition keep as center (midpoint) so existing logic that references targetPosition still works.
                        // position = topStart, position2 = bottomStart; the game loop / animation will move them to finalTop / finalBottom at approachEnd.
                        let new = ActiveNote(
                            id: newID,
                            sourceID: note.id,
                            angleDegrees: 0.0,
                            position: topStart,
                            targetPosition: CGPoint(x: target.x, y: target.y), // keep center as logical target
                            hitTime: note.time,
                            spawnTime: info.spawnTime,
                            isClear: false,
                            isTap: true,
                            position2: bottomStart
                        )

                        // store per-note "final positions" so we can update them in game loop or animate to them
                        // You may already set approach start/end times elsewhere; ensure the game loop lerps from startPosition->targetPosition.
                        // For immediate compatibility with existing animation-based code, animate position -> finalTop / position2 -> finalBottom
                        self.activeNotes.append(new)

                        // Animate (if you still use withAnimation; if you've switched to timer-driven movement, set approach times instead)
                        if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                            // If you use timer-driven movement: set startPosition/approachTimes (see previous instructions).
                            // If you still animate with withAnimation, animate to finalTop/finalBottom:
                            withAnimation(.linear(duration: approachDuration)) {
                                self.activeNotes[idx].position = finalTop
                                self.activeNotes[idx].position2 = finalBottom
                            }
                        }
                    } else if isHoldNote {
                        // Hold: start positions like tap, but mark holdEndTime
                        let topStart = CGPoint(x: target.x, y: target.y - approachDistance - 80)
                        let bottomStart = CGPoint(x: target.x, y: target.y + approachDistance + 80)

                        // compute total hold seconds from sheet (guard)
                        let totalHoldSeconds = max(0.0, (note.holdEndTime ?? note.time) - note.time)

                        // assume newID already created outside
                        let nowDev = currentDeviceTime()
                        let approachStartDev = (audioPlayer != nil && audioStartDeviceTime != nil) ? (audioStartDeviceTime! + spawnTime) : (Date().timeIntervalSince1970 + spawnTime)
                        let approachEndDev = approachStartDev + approachDuration

                        // create new ActiveNote
                        var new = ActiveNote(
                            id: newID,
                            sourceID: note.id,
                            angleDegrees: note.angleDegrees,
                            position: startPos,                 // start position
                            targetPosition: target,
                            hitTime: note.time,
                            spawnTime: spawnTime,
                            isClear: false
                        )
                        new.startPosition = startPos
                        new.approachStartDeviceTime = (audioPlayer != nil) ? approachStartDev : nil
                        new.approachStartWallTime = (audioPlayer == nil) ? Date().timeIntervalSince1970 + spawnTime : nil
                        new.approachEndDeviceTime = (audioPlayer != nil) ? approachEndDev : nil
                        new.approachEndWallTime = (audioPlayer == nil) ? (Date().timeIntervalSince1970 + spawnTime + approachDuration) : nil
                        new.approachDuration = approachDuration

                        // for tap: also set position2 start
                        if note.noteType == "tap" {
                            new.isTap = true
                            new.position2 = bottomStart // earlier computed
                        }

                        // for hold: set hold initial values (as before)
                        if note.noteType == "hold" {
                            new.isHold = true
                            new.holdFillScale = 0.0
                            new.holdTrim = 1.0
                            new.holdTotalSeconds = totalHoldSeconds
                            new.holdRemainingSeconds = totalHoldSeconds
                            new.holdPressedByUser = false
                            new.holdWasReleased = false
                        }

                        // append to activeNotes -- do not call withAnimation to move it
                        self.activeNotes.append(new)

                        // NOTE: do NOT call withAnimation(.linear(duration:)) to change position to target.
                        // The gameLoopTick will update position across time. If you want an initial visual "pop-in" you can still animate opacity or scale.

                        // holdFill animation duration (user-tunable fraction of approachDuration)
                        let fraction = max(0.0, min(2.0, self.holdFillDurationFraction))
                        let holdFillDuration = max(0.0, approachDuration * fraction)

                        // Animate inner white circle 0 -> 1 (when full, we enter "hold ready" state)
                        if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                            withAnimation(.linear(duration: holdFillDuration)) {
                                self.activeNotes[idx].holdFillScale = 1.0
                            }
                        }

                        // When fill completes, set holdStarted and record start times, and start a timer
                        // Replace the whole DispatchQueue.main.asyncAfter(... holdFillDuration ...) block for hold notes:
                        DispatchQueue.main.asyncAfter(deadline: .now() + holdFillDuration) {
                            // ensure note still exists
                            guard let idx2 = self.activeNotes.firstIndex(where: { $0.id == newID }) else { return }

                            // mark started and record start times
                            self.activeNotes[idx2].holdStarted = true
                            if let player = self.audioPlayer {
                                self.activeNotes[idx2].holdStartDeviceTime = player.deviceCurrentTime
                            } else {
                                self.activeNotes[idx2].holdStartWallTime = Date().timeIntervalSince1970
                            }
                            // set last tick to now
                            if let nowDev = self.activeNotes[idx2].holdStartDeviceTime ?? self.activeNotes[idx2].holdStartWallTime {
                                self.activeNotes[idx2].holdLastTickDeviceTime = nowDev
                            }

                            // If user already has a finger down near this note, treat it as a press (handles pre-fill presses)
                            if self.isFingerDown, let fingerLoc = self.fingerLocation {
                                let d = hypot(self.activeNotes[idx2].targetPosition.x - fingerLoc.x,
                                              self.activeNotes[idx2].targetPosition.y - fingerLoc.y)
                                if d <= self.hitRadius && !self.activeNotes[idx2].holdPressedByUser && !self.activeNotes[idx2].holdWasReleased {
                                    self.activeNotes[idx2].holdPressedByUser = true
                                    if let nowDev = self.activeNotes[idx2].holdStartDeviceTime ?? self.activeNotes[idx2].holdStartWallTime {
                                        self.activeNotes[idx2].holdPressDeviceTime = nowDev
                                        self.activeNotes[idx2].holdLastTickDeviceTime = nowDev
                                    }
                                    // optional: visual cue
                                    // self.showJudgement(text: "OK", color: .white)
                                }
                            }

                            // create a timer that updates holdTrim (remaining fraction) at ~30Hz
                            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                            let interval = DispatchTimeInterval.milliseconds(33)
                            timer.schedule(deadline: .now(), repeating: interval)
                            timer.setEventHandler {
                                // find note index again (ActiveNote may have been removed)
                                guard let idx3 = self.activeNotes.firstIndex(where: { $0.id == newID }) else {
                                    timer.cancel()
                                    self.holdTimers[newID] = nil
                                    return
                                }

                                // if this hold was already released by user (and judgement done) => cancel timer
                                if self.activeNotes[idx3].holdWasReleased {
                                    timer.cancel()
                                    self.holdTimers[newID] = nil
                                    return
                                }

                                // compute now (device or wall)
                                var nowDev: TimeInterval
                                if let player = self.audioPlayer {
                                    nowDev = player.deviceCurrentTime
                                } else {
                                    nowDev = Date().timeIntervalSince1970
                                }

                                // compute holdEnd device time (if available)
                                var holdEndDev: TimeInterval? = nil
                                if let player = self.audioPlayer, let startDev = self.audioStartDeviceTime, let hed = self.activeNotes[idx3].holdEndTime {
                                    holdEndDev = startDev + hed
                                } else if let sd = self.startDate, let hed = self.activeNotes[idx3].holdEndTime {
                                    holdEndDev = sd.timeIntervalSince1970 + hed
                                } else if let start = self.activeNotes[idx3].holdStartDeviceTime {
                                    holdEndDev = start + self.activeNotes[idx3].holdTotalSeconds
                                } else if let start = self.activeNotes[idx3].holdStartWallTime {
                                    holdEndDev = start + self.activeNotes[idx3].holdTotalSeconds
                                }

                                // compute delta since last tick and update lastTick
                                let lastTick = self.activeNotes[idx3].holdLastTickDeviceTime ?? nowDev
                                let delta = max(0.0, nowDev - lastTick)
                                self.activeNotes[idx3].holdLastTickDeviceTime = nowDev

                                // If user is currently pressing, decrement remaining
                                if self.activeNotes[idx3].holdPressedByUser {
                                    let newRemaining = max(0.0, self.activeNotes[idx3].holdRemainingSeconds - delta)
                                    self.activeNotes[idx3].holdRemainingSeconds = newRemaining
                                    let total = max(0.0001, self.activeNotes[idx3].holdTotalSeconds)
                                    self.activeNotes[idx3].holdTrim = min(1.0, max(0.0, newRemaining / total))

                                    // If remaining reached zero while pressing -> immediate completion (PERFECT)
                                    if newRemaining <= 0.0001 {
                                        // cancel timer
                                        timer.cancel()
                                        self.holdTimers[newID] = nil

                                        if self.isStopped {
                                            // reflect visual completion but keep note if stopped
                                            self.activeNotes[idx3].holdRemainingSeconds = 0.0
                                            self.activeNotes[idx3].holdTrim = 0.0
                                            self.activeNotes[idx3].holdCompletedWhileStopped = true
                                            return
                                        }

                                        // Award PERFECT immediately (no need to release)
                                        self.perfectCount += 1
                                        self.score += 3
                                        self.combo += 1
                                        if self.combo > self.maxCombo { self.maxCombo = self.combo }
                                        self.showJudgement(text: "PERFECT", color: .green)

                                        // remove visual
                                        withAnimation(.easeIn(duration: 0.12)) {
                                            self.activeNotes.removeAll { $0.id == newID }
                                        }
                                        return
                                    }
                                } else {
                                    // not pressing: check for holdEnd passed without press -> miss (after a short grace)
                                    if let hed = holdEndDev {
                                        if nowDev - hed > 0.5 && !self.activeNotes[idx3].holdPressedByUser {
                                            if self.isStopped {
                                                return
                                            }
                                            // Miss: user never pressed
                                            self.missCount += 1
                                            self.combo = 0
                                            self.consecutiveCombo = 0
                                            self.showJudgement(text: "MISS", color: .red)
                                            timer.cancel()
                                            self.holdTimers[newID] = nil
                                            withAnimation(.easeIn(duration: 0.12)) {
                                                self.activeNotes.removeAll { $0.id == newID }
                                            }
                                            return
                                        }
                                    }
                                }

                                // Additionally: if holdEnd time passed and user is pressing (but holdRemaining not yet zero because holdTotalSeconds computed differently),
                                // treat this as completion as well (covers sheet-based holdEnd definitions).
                                if let hed = holdEndDev, nowDev >= hed, self.activeNotes[idx3].holdPressedByUser {
                                    // cancel timer
                                    timer.cancel()
                                    self.holdTimers[newID] = nil

                                    if self.isStopped {
                                        self.activeNotes[idx3].holdRemainingSeconds = 0.0
                                        self.activeNotes[idx3].holdTrim = 0.0
                                        self.activeNotes[idx3].holdCompletedWhileStopped = true
                                        return
                                    }

                                    self.perfectCount += 1
                                    self.score += 3
                                    self.combo += 1
                                    if self.combo > self.maxCombo { self.maxCombo = self.combo }
                                    self.showJudgement(text: "PERFECT", color: .green)
                                    withAnimation(.easeIn(duration: 0.12)) {
                                        self.activeNotes.removeAll { $0.id == newID }
                                    }
                                    return
                                }
                            } // end eventHandler

                            // store and start
                            self.holdTimers[newID] = timer
                            timer.resume()
                        } // end dispatch after fill

                        // animate approach (move pieces to target)
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
                    // --- replace: spawn 実行時に deleteWork を生成して id に紐付け、spawn から lifeDuration 後に実行する ---
                    // 変更点: hold ノーツの場合は通常の lifeDuration 自動削除をスキップする（hold タイマーで管理する）
                    // Replace: spawn 実行時に deleteWork を生成して id に紐付け、spawn から lifeDuration 後に実行する
                    // 変更点: hold ノーツの場合は通常の lifeDuration 自動削除をスキップ（hold タイマーで管理）
                    let deleteWork = DispatchWorkItem {
                        DispatchQueue.main.async {
                            // ノートがまだ存在するか？
                            guard self.activeNotes.firstIndex(where: { $0.id == newID }) != nil else {
                                self.autoDeleteWorkItems[newID] = nil
                                return
                            }

                            // フリック済みなら何もしない
                            if self.flickedNoteIDs.contains(newID) {
                                self.autoDeleteWorkItems[newID] = nil
                                return
                            }

                            // HOLD ノーツはここで自動削除しない（hold タイマーが miss/completion を管理する）
                            if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }), self.activeNotes[idx].isHold {
                                // keep mapping but do not remove — timer will handle miss/completion
                                self.autoDeleteWorkItems[newID] = nil
                                return
                            }

                            // 通常ノーツ用の自動削除（Miss 扱い）
                            withAnimation(.easeIn(duration: 0.18)) {
                                self.activeNotes.removeAll { $0.id == newID }
                            }
                            self.combo = 0
                            self.consecutiveCombo = 0
                            self.missCount += 1
                            self.autoDeleteWorkItems[newID] = nil
                            self.showJudgement(text: "MISS", color: .red)
                        }
                    }

                    // store and schedule deleteWork relative to now (spawn moment)
                    // For hold notes: do not schedule automatic lifeDuration delete
                    self.autoDeleteWorkItems[newID] = deleteWork
                    if !isHoldNote {
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.lifeDuration, execute: deleteWork)
                    } else {
                        // optional: schedule a very late fallback if you want, but usually not necessary:
                        // let fallback = DispatchWorkItem { DispatchQueue.main.async { /* cleanup if still present */ } }
                        // DispatchQueue.main.asyncAfter(deadline: .now() + 600.0, execute: fallback)
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
            // --- BEFORE scheduling --- (既に spawnWork, clearWork が作られている想定)

            // store scheduling info (use device time if audio available, else wall time)
            if let player = audioPlayer, let startDevice = audioStartDeviceTime {
                let deviceNow = player.deviceCurrentTime
                let spawnDeviceTime = startDevice + spawnTime
                let clearDeviceTime = startDevice + note.time

                // keep metadata for pause/resume
                scheduledNoteInfos[newID] = (sheetNote: note, target: target, approachDuration: approachDuration, spawnTime: spawnTime, clearTime: note.time)

                // store execution times (device clock)
                scheduledSpawnTimes[newID] = spawnDeviceTime
                scheduledClearTimes[newID] = clearDeviceTime

                // keep references to work items so we can cancel them on pause
                scheduledSpawnWorkItemsByNote[newID] = spawnWork
                scheduledClearWorkItemsByNote[newID] = clearWork

                let spawnDelay = max(0.0, spawnDeviceTime - deviceNow)
                let clearDelay = max(0.0, clearDeviceTime - deviceNow)

                DispatchQueue.main.asyncAfter(deadline: .now() + spawnDelay, execute: spawnWork)
                DispatchQueue.main.asyncAfter(deadline: .now() + clearDelay, execute: clearWork)
            } else {
                // wall-clock fallback
                let wallNow = Date().timeIntervalSince1970
                let spawnExecuteAt = wallNow + spawnTime
                let clearExecuteAt = wallNow + note.time

                scheduledNoteInfos[newID] = (sheetNote: note, target: target, approachDuration: approachDuration, spawnTime: spawnTime, clearTime: note.time)

                scheduledSpawnTimes[newID] = spawnExecuteAt
                scheduledClearTimes[newID] = clearExecuteAt

                scheduledSpawnWorkItemsByNote[newID] = spawnWork
                scheduledClearWorkItemsByNote[newID] = clearWork

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
        stopGameLoopIfNeeded()
        // stop audio
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        // stop/teardown background
        if backgroundIsVideo {
            backgroundPlayer?.pause()
            backgroundPlayerLooper = nil
            backgroundPlayer = nil
        }
        backgroundImage = nil
        backgroundIsVideo = false
        backgroundFilename = nil
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
        // handleFlick の先頭に置く
        guard !isStopped else { return }
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
        // handleGlobalFlick の先頭に置く
        guard !isStopped else { return }
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
