// Minimal global SFX helper (all songs use the same sounds).
// Add this file to your project. It extends a simple SoundEffectManager (or can be used standalone).
// Provide the audio files in your bundle (bundled-resources or main bundle) or in Documents.
// Default filenames below can be changed to match your assets.

import Foundation
import AVFoundation
import UIKit

public final class GlobalSFX {
    public static let shared = GlobalSFX()

    // Default filenames (change to match your assets)
    public var tapPerfect = "tap_perfect.wav"
    public var tapGood    = "tap_good.wav"
    public var tapOk      = "tap_ok.wav"

    public var flickPerfect = "flick_perfect.wav"
    public var flickGood    = "flick_good.wav"
    public var flickOk      = "flick_ok.wav"

    // Hold loop filename (will be played as looping while holding)
    public var holdLoop = "hold_loop.wav"

    // Miss sound (used for misses)
    public var miss = "miss.wav"

    // internal cache of AVAudioPlayers
    private var players: [String: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "global.sfx.queue")

    private init() {}

    // lower-level play helper (non-loop)
    private func playFile(_ filename: String, volume: Float = 10.0) {
        queue.async {
            guard !filename.isEmpty else { return }
            let key = filename
            if let p = self.players[key] {
                p.currentTime = 0
                p.volume = volume
                p.play()
                return
            }

            // try Documents first
            let fm = FileManager.default
            if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                let candidate = docs.appendingPathComponent(filename)
                if fm.fileExists(atPath: candidate.path), let p = self.makePlayer(url: candidate, volume: volume) {
                    self.players[key] = p
                    p.play()
                    return
                }
            }

            // try bundle (bundled-resources then root)
            let ext = (filename as NSString).pathExtension
            let name = (filename as NSString).deletingPathExtension
            if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: "bundled-resources") ??
                         Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext) {
                if let p = self.makePlayer(url: url, volume: volume) {
                    self.players[key] = p
                    p.play()
                    return
                }
            }

            // try common extensions if none provided
            if ext.isEmpty {
                for alt in ["wav","mp3","m4a","caf","aiff"] {
                    if let url = Bundle.main.url(forResource: name, withExtension: alt, subdirectory: "bundled-resources") ??
                                 Bundle.main.url(forResource: name, withExtension: alt) {
                        if let p = self.makePlayer(url: url, volume: volume) {
                            self.players[key] = p
                            p.play()
                            return
                        }
                    }
                }
            }
            // nothing found -> ignore
        }
    }

    // loop control for hold
    private func playLoopFile(_ filename: String, volume: Float = 1.0) {
        queue.async {
            guard !filename.isEmpty else { return }
            if let p = self.players[filename] {
                p.numberOfLoops = -1
                p.volume = volume
                if !p.isPlaying { p.play() }
                return
            }

            // try to locate file
            let fm = FileManager.default
            var url: URL? = nil
            if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                let candidate = docs.appendingPathComponent(filename)
                if fm.fileExists(atPath: candidate.path) { url = candidate }
            }
            if url == nil {
                let ext = (filename as NSString).pathExtension
                let name = (filename as NSString).deletingPathExtension
                url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: "bundled-resources") ??
                      Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? nil : ext)
            }
            if let u = url, let p = self.makePlayer(url: u, volume: volume) {
                p.numberOfLoops = -1
                self.players[filename] = p
                p.play()
            }
        }
    }

    private func stopLoopFile(_ filename: String) {
        queue.async {
            if let p = self.players[filename] {
                p.stop()
                p.currentTime = 0
            }
        }
    }

    private func makePlayer(url: URL, volume: Float) -> AVAudioPlayer? {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.volume = volume
            p.numberOfLoops = 0
            return p
        } catch {
            print("GlobalSFX: failed to create player for \(url): \(error)")
            return nil
        }
    }

    // MARK: - Public convenience APIs used from ContentView

    public func playTapJudgement(_ judgement: String) {
        switch judgement {
        case "PERFECT": playFile(tapPerfect)
        case "GOOD":    playFile(tapGood)
        case "OK":      playFile(tapOk)
        default:        playFile(miss)
        }
    }

    public func playFlickJudgement(_ judgement: String) {
        switch judgement {
        case "PERFECT": playFile(flickPerfect)
        case "GOOD":    playFile(flickGood)
        case "OK":      playFile(flickOk)
        default:        playFile(miss)
        }
    }
    

    // hold loop control
    public func startHoldLoop() {
        if !holdLoop.isEmpty { playLoopFile(holdLoop) }
    }
    public func stopHoldLoop() {
        if !holdLoop.isEmpty { stopLoopFile(holdLoop) }
    }

    // miss (explicit)
    public func playMiss() {
        playFile(miss)
    }
}
