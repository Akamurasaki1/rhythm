// Minimal facade to satisfy calls to PlaybackController.shared.*
// If you already have a real PlaybackController implementation, keep that and delete this file.

import Foundation
import AVFoundation
import UIKit

public final class PlaybackController {
    public static let shared = PlaybackController()

    public var sheetNotesToPlay: [SheetNote] = []
    public var notesToPlay: [Note] = []
    public var preparedAudioPlayer: AVAudioPlayer? = nil

    private init() {}

    public func loadSheet(_ sheet: Sheet, userID: String) {
        self.sheetNotesToPlay = sheet.notes
        self.notesToPlay = sheet.notes.asNotes()
        print("PlaybackController.facade: loaded sheet id=\(sheet.id ?? "<nil>")")
    }

    public func loadAudioFile(url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("PlaybackController.facade: audio session error: \(error)")
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                DispatchQueue.main.async {
                    self.preparedAudioPlayer = player
                    print("PlaybackController.facade: prepared audio for \(url.lastPathComponent)")
                }
            } catch {
                print("PlaybackController.facade: failed to prepare audio: \(error)")
            }
        }
    }

    public func loadAndStart(sheet: Sheet, userID: String, in size: CGSize) {
        loadSheet(sheet, userID: userID)
        if let audio = ScoreStore.shared.audioURL(for: sheet, userID: userID) {
            loadAudioFile(url: audio)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.startPlayback(in: size)
        }
    }

    public func startPlayback(in size: CGSize) {
        print("PlaybackController.facade: startPlayback (notes=\(notesToPlay.count))")
        NotificationCenter.default.post(name: .playSheet, object: nil, userInfo: ["facadeStart": true])
    }
}
