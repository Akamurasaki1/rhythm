//
//  rhythmApp.swift
//  rhythm
//
//  Created by Karen Naito on 2025/11/15.
//  Updated by assistant to make startup/navigation robust
//

//
//  rhythmApp.swift
//  rhythm
//
//  Created by Karen Naito on 2025/11/15.
//  Updated: make title->songSelect transition async to avoid timing-related crash
//

import SwiftUI

@main
struct SYNqFliQApp: App {
    private enum AppState {
        case title
        case songSelect
        case playing
    }

    @State private var appState: AppState = .title

    // selection placeholders (can be wired later)
    @State private var selectedSongID: String? = nil
    @State private var selectedDifficulty: String? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState {
                case .title:
                    TitleView(
                        onStart: {
                            // perform transition asynchronously to avoid mutating view hierarchy
                            // during the button's own animation/gesture handling.
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut) {
                                    appState = .songSelect
                                }
                            }
                        },
                        onOpenSettings: {
                            // present settings if needed
                        },
                        onShowCredits: {
                            // present credits if needed
                        }
                    )
                case .songSelect:
                    // provide a safe (possibly empty) songs list to avoid heavy work during init
                    SongSelectionView(
                        songs: [], // TODO: inject real song summaries here
                        onClose: {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut) {
                                    appState = .title
                                }
                            }
                        },
                        onChoose: { songSummary, difficulty in
                            // store selection and move to play screen
                            selectedSongID = songSummary.id
                            selectedDifficulty = difficulty
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut) {
                                    appState = .playing
                                }
                            }
                        }
                    )
                case .playing:
                    ContentView()
                }
            }
        }
    }
}
