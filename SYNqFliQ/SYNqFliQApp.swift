import SwiftUI
import FirebaseCore

@main
struct SYNqFliQApp: App {
    init() {
        // Firebase デバッグログを有効化（リリース時は元に戻す）
        FirebaseConfiguration.shared.setLoggerLevel(.debug)

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("DBG: Firebase configured")
        }
    }
    enum AppState { case title, songSelect, playing, tutorial }

    @StateObject private var appModel = AppModel()
    @StateObject private var settings = SettingsStore()
    @State private var appState: AppState = .title
    @State private var showingSettings: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                // if model explicitly requests song selection, honor it first
                if appModel.showingSongSelection {
                    songSelectionView()
                        .environmentObject(appModel)
                        .environmentObject(settings) // <-- ensure SettingsStore is available here too
                } else {
                    switch appState {
                    case .title:
                        TitleView(onStart: {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut) {
                                    appState = .songSelect
                                }
                            }
                        }, onOpenSettings: {
                            // TitleView の設定ボタンから呼び出される想定
                            showingSettings = true
                        }, onShowCredits: {})
                        .environmentObject(appModel)
                        .environmentObject(settings)


                    case .songSelect:
                        songSelectionView()
                            .environmentObject(appModel)
                            .environmentObject(settings)

                    case .playing:
                        ContentView()
                            .environmentObject(appModel)
                            .environmentObject(settings)
                    case .tutorial:
                        TutorialView()
                            .environmentObject(appModel)
                            .environmentObject(settings)

                    }
                }
            }
            // settings sheet presentation
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(settings)
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

    // Replace the existing songSelectionView() implementation with this function.
    // This groups bundledSheets by sheet.title and builds one SongSummary per title
    // (uses the first occurrence as the representative entry).

    @ViewBuilder
    private func songSelectionView() -> some View {
        // Build entries with index so we can keep bundledIndex pointing to a concrete file
        let entries = appModel.bundledSheets.enumerated().map { (index: $0.offset, entry: $0.element) }
        // Group by title
        let groupedByTitle = Dictionary(grouping: entries, by: { $0.entry.sheet.title })
        // Create one SongSummary per title (use first occurrence as representative)
        let summaries: [SongSelectionView.SongSummary] = groupedByTitle.map { (_, list) in
            let representative = list[0]
            return SongSelectionView.SongSummary(
                id: representative.entry.filename,
                title: representative.entry.sheet.title,
                thumbnailFilename: representative.entry.sheet.thumbnailFilename ?? representative.entry.sheet.backgroundFilename,
                bundledIndex: representative.index
            )
        }
        // Optional: sort alphabetically (or keep original order as you prefer)
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

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
