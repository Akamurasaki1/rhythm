import SwiftUI

@main
struct SYNqFliQApp: App {
    enum AppState { case title, songSelect, playing }

    @StateObject private var appModel = AppModel()
    @State private var appState: AppState = .title

    // selected sheet info (filled in onChoose)
    @State private var selectedSheetFilename: String? = nil
    @State private var selectedDifficulty: String? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState {
                case .title:
                    TitleView(onStart: {
                        // async transition to avoid UI timing issues
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut) {
                                appState = .songSelect
                            }
                        }
                    }, onOpenSettings: {}, onShowCredits: {})
                        .environmentObject(appModel)
                case .songSelect:
                    // map bundledSheets -> SongSelectionView.SongSummary
                    let summaries: [SongSelectionView.SongSummary] = appModel.bundledSheets.enumerated().map { idx, pair in
                        SongSelectionView.SongSummary(
                            id: pair.filename,
                            title: pair.sheet.title,
                            thumbnailFilename: pair.sheet.backgroundFilename,
                            bundledIndex: idx
                        )
                    }
                    SongSelectionView(songs: summaries, onClose: {
                        DispatchQueue.main.async {
                            withAnimation { appState = .title }
                        }
                    }, onChoose: { songSummary, difficulty in
                        // store and transition to gameplay
                        selectedSheetFilename = songSummary.id
                        selectedDifficulty = difficulty
                        DispatchQueue.main.async {
                            withAnimation { appState = .playing }
                        }
                    })
                    .environmentObject(appModel)
                case .playing:
                    // TODO: pass selectedSheet into ContentView if you update its initializer.
                    ContentView()
                        .environmentObject(appModel)
                }
            }
        }
    }
}
