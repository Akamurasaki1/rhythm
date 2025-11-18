import SwiftUI

@main
struct SYNqFliQApp: App {
    enum AppState { case title, songSelect, playing }

    @StateObject private var appModel = AppModel()
    @State private var appState: AppState = .title

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState {
                case .title:
                    TitleView(onStart: {
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut) {
                                appState = .songSelect
                            }
                        }
                    }, onOpenSettings: {}, onShowCredits: {})
                        .environmentObject(appModel)

                case .songSelect:
                    let summaries: [SongSelectionView.SongSummary] = appModel.bundledSheets.enumerated().map { idx, pair in
                        SongSelectionView.SongSummary(
                            id: pair.filename,
                            title: pair.sheet.title,
                            // prefer explicit thumbnail; fall back to background if no thumbnail provided
                            thumbnailFilename: pair.sheet.thumbnailFilename ?? pair.sheet.backgroundFilename,
                            bundledIndex: idx
                        )
                    }

                    SongSelectionView(songs: summaries, onClose: {
                        DispatchQueue.main.async {
                            withAnimation { appState = .title }
                        }
                    }, onChoose: { songSummary, difficulty in
                        // record selection into appModel, then go to playing
                        appModel.selectedSheetFilename = songSummary.id
                        appModel.selectedDifficulty = difficulty
                        DispatchQueue.main.async {
                            withAnimation { appState = .playing }
                        }
                    })
                    .environmentObject(appModel)

                case .playing:
                    // ContentView reads background image via AppModel.selectedSheet (EnvironmentObject)
                    ContentView()
                        .environmentObject(appModel)
                }
            }
        }
    }
}
