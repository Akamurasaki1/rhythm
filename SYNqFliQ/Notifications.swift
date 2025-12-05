//
//  Notifications.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/04.
//


// Adds a typed notification name used for play requests from SongSelectionView -> ContentView
// Place this file anywhere in your app target (e.g., Utilities/).

import Foundation

extension Notification.Name {
    /// Post a play request with userInfo: ["sheetID": String, "userID": String?]
    static let playSheet = Notification.Name("SYNqFliQ.PlaySheet")

    /// Posted just before playback preparation begins (UI can show loading)
    static let playbackWillStart = Notification.Name("SYNqFliQ.PlaybackWillStart")

    /// Posted once playback has started (UI should hide loading)
    static let playbackDidStart = Notification.Name("SYNqFliQ.PlaybackDidStart")
}
