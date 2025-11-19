import SwiftUI

@main
struct SYNqFliQApp: App {
    enum AppState { case title, songSelect, playing }

    @StateObject private var appModel = AppModel()
    @State private var appState: AppState = .title

    var body: some Scene {
        WindowGroup {
            Group {
                // if model explicitly requests song selection, honor it first
                if appModel.showingSongSelection {
                    songSelectionView()
                        .environmentObject(appModel)
                } else {
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
                        songSelectionView()
                            .environmentObject(appModel)

                    case .playing:
                        ContentView()
                            .environmentObject(appModel)
                    }
                }
            }
            .onChange(of: appModel.showingSongSelection) { showing in
                print("DBG: App observed appModel.showingSongSelection = \(showing) (selected = \(String(describing: appModel.selectedSheetFilename)))")
                if showing {
                    appState = .songSelect
                }
            }
            .onChange(of: appModel.selectedSheetFilename) { sel in
                print("DBG: App observed selectedSheetFilename -> \(String(describing: sel))")
                if sel != nil {
                    appState = .playing
                    appModel.closeSongSelection()
                }
            }
            .onChange(of: appState) { st in
                print("DBG: App local appState changed -> \(st)")
            }
        }
    }

    @ViewBuilder
    private func songSelectionView() -> some View {
        let summaries: [SongSelectionView.SongSummary] = appModel.bundledSheets.enumerated().map { idx, pair in
            SongSelectionView.SongSummary(
                id: pair.filename,
                title: pair.sheet.title,
                thumbnailFilename: pair.sheet.thumbnailFilename ?? pair.sheet.backgroundFilename,
                bundledIndex: idx
            )
        }

        SongSelectionView(songs: summaries, onClose: {
            DispatchQueue.main.async {
                withAnimation {
                    appModel.closeSongSelection()
                    appState = .title
                }
            }
        }, onChoose: { songSummary, difficulty in
            print("DBG: SongSelection onChoose -> id=\(songSummary.id) difficulty=\(String(describing: difficulty))")
            appModel.selectedSheetFilename = songSummary.id
            appModel.selectedDifficulty = difficulty
            appModel.closeSongSelection()
            DispatchQueue.main.async {
                withAnimation { appState = .playing }
            }
        })
    }
}
