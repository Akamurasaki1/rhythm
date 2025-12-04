//
//  PlaybackController.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/04.
//


// Lightweight facade to satisfy references to PlaybackController in various views.
// This is a minimal, safe stub that compiles and provides the small API SongSelectionView/ContentView expect.
// Replace or remove this file once you wire the real playback logic in ContentView or a dedicated controller.

import Foundation
import AVFoundation
import UIKit

public final class PlaybackController {
    public static let shared = PlaybackController()

    // public-ish state used by other code; keep names aligned with what your views expect
    public var sheetNotesToPlay: [SheetNote] = []
    public var notesToPlay: [Note] = []
    public var preparedAudioPlayer: AVAudioPlayer? = nil

    private init() {}

    /// Load sheet data into the controller (does not start playback).
    public func loadSheet(_ sheet: Sheet, userID: String) {
        self.sheetNotesToPlay = sheet.notes
        self.notesToPlay = sheet.notes.asNotes()
        print("PlaybackController.facade: loaded sheet id=\(sheet.id ?? "<nil>") title=\(sheet.title)")
    }

    /// Prepare audio player for url (stored to preparedAudioPlayer). Non-blocking.
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

    /// Convenience: load sheet, optionally audio via ScoreStore, and then call startPlayback(in:).
    public func loadAndStart(sheet: Sheet, userID: String, in size: CGSize) {
        loadSheet(sheet, userID: userID)
        if let audioURL = ScoreStore.shared.audioURL(for: sheet, userID: userID) {
            loadAudioFile(url: audioURL)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.startPlayback(in: size)
        }
    }

    /// Minimal startPlayback placeholder. Your real playback logic lives in ContentView currently;
    /// this stub simply logs and posts a notification as a hint. Replace with real code if desired.
    public func startPlayback(in size: CGSize) {
        print("PlaybackController.facade: startPlayback called (notes=\(notesToPlay.count))")
        NotificationCenter.default.post(name: .playSheet, object: nil, userInfo: ["facadeStart": true])
    }
}