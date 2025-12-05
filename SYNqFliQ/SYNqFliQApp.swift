//
//  SYNqFliQApp.swift
//  SYNqFliQ
//
//  Updated: added .History handling and a lightweight HistoryScreen.
//  Place in your project replacing the existing SYNqFliQApp.swift (or merge changes).
//
import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SYNqFliQApp: App {
    init() {
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("DBG: Firebase configured")
        }
    }

    enum AppState { case title, songSelect, playing, tutorial, history, chapterSelect, credits, importer, stories }

    @StateObject private var appModel = AppModel()
    @StateObject private var settings = SettingsStore()
    @State private var appState: AppState = .title
    @State private var showingSettings: Bool = false

    var body: some Scene {
        WindowGroup {
            // Single root Group — all child views receive the same environment objects.
            Group {
                // honor explicit song-selection request first
                if appModel.showingSongSelection {
                   // SongListView().environmentObject(appModel)
                    songSelectionView()
                } else {
                    switch appState {
                    case .title:
                        TitleView(
                            onStart: {
                                DispatchQueue.main.async { withAnimation(.easeInOut) { appState = .songSelect } }
                            },
                            onOpenSettings: {
                                showingSettings = true
                            },
                            onShowCredits: {
                                DispatchQueue.main.async { withAnimation(.easeInOut) { appState = .credits } }
                            },
                            onShowTutorial: {
                                DispatchQueue.main.async { withAnimation(.easeInOut) { appState = .tutorial } }
                            },
                            onShowHistories: {
                                DispatchQueue.main.async { withAnimation(.easeInOut) { appState = .history } }
                            },
                            onShowChapters: {
                                DispatchQueue.main.async { withAnimation { appState = .chapterSelect } }
                            },
                            onShowImporter: {
                                DispatchQueue.main.async { withAnimation { appState = .importer } }
                            },
                            onShowStories: {
                                DispatchQueue.main.async { withAnimation { appState = .stories } }
                            }
                        )

                    case .songSelect:
                       songSelectionView()
                        //SongListView().environmentObject(appModel)
                    case .playing:
                        // show the main ContentView when appState is playing
                        ContentView()

                    case .tutorial:
                        TutorialView(onStart: {
                            DispatchQueue.main.async { withAnimation { appState = .title } }
                        })

                    case .history:
                        HistoryScreen(onClose: {
                            withAnimation { appState = .title }
                        }, onPlayRecord: { rec in
                            appModel.selectedSheetFilename = rec.sheetFilename
                            appModel.selectedDifficulty = rec.difficulty
                            appModel.closeSongSelection()
                            DispatchQueue.main.async { withAnimation { appState = .playing } }
                        })

                    case .chapterSelect:
                        chapterSelectionView()

                    case .credits:
                        CreditsView(onClose: {
                            DispatchQueue.main.async { withAnimation { appState = .title } }
                        })

                    case .importer:
                        ImportScoreView(onClose: {
                            DispatchQueue.main.async { withAnimation { appState = .title } }
                        })

                    case .stories:
                        StoriesView(onClose: {
                            DispatchQueue.main.async { withAnimation { appState = .title } }
                        })
                    }
                }
            }
            // inject environment objects once for the whole group
            .environmentObject(appModel)
            .environmentObject(settings)
            // perform startup refresh
            .onAppear {
                let uid = AuthManager.shared.firebaseUser?.uid ?? "local-user"
                ScoreStore.shared.refresh(for: uid)
            }
            // settings sheet
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(settings)
            }
            // keep previous onChange handlers
            .onChange(of: appModel.showingSongSelection) { showing in
                if showing { appState = .songSelect }
            }
            .onChange(of: appModel.selectedSheetFilename) { sel in
                if sel != nil {
                    appState = .playing
                    appModel.closeSongSelection()
                }
            }
        }
    }

    // put this inside SYNqFliQApp struct (alongside songSelectionView)
    @ViewBuilder
    private func chapterSelectionView() -> some View {
        let chapters = [
            Chapter(id: "all", title: "All Songs", subtitle: "Browse every song"),
            Chapter(id: "LeaF", title: "LeaF", subtitle: "LeaF songs", thumbnailFilename: "LeaF_t.png"),
            Chapter(id: "Akamurasaki", title: "Akamurasaki", subtitle: "Akamurasaki songs", thumbnailFilename: "Akamurasaki_t.jpg"),
            Chapter(id: "special", title: "Special", subtitle: "Event tracks")
        ]

        ChapterSelectionView(chapters: chapters, onSelect: { ch in
            appModel.selectedChapter = ch.id
            DispatchQueue.main.async { withAnimation { appState = .songSelect } }
        }, onClose: {
            DispatchQueue.main.async { withAnimation { appState = .title } }
        })
        .environmentObject(appModel)
        .environmentObject(settings)
    }

    @ViewBuilder
    private func songSelectionView() -> some View {
        let entries = appModel.bundledSheets.enumerated().map { (index: $0.offset, entry: $0.element) }

        let filteredEntries: [(index: Int, entry: BundledSheet)] = {
            guard let ch = appModel.selectedChapter, !ch.isEmpty, ch != "all" else { return entries }
            return entries.filter { pair in
                return (pair.entry.sheet.chapter ?? "all") == ch
            }
        }()

        let groupedByTitle = Dictionary(grouping: filteredEntries, by: { $0.entry.sheet.title })
        let summaries: [SongSelectionView.SongSummary] = groupedByTitle.map { (_, list) in
            let representative = list[0]
            return SongSelectionView.SongSummary(
                id: representative.entry.filename,
                title: representative.entry.sheet.title,
                composer: representative.entry.sheet.composer ?? "Other",
                thumbnailFilename: representative.entry.sheet.thumbnailFilename ?? representative.entry.sheet.backgroundFilename,
                bundledIndex: representative.index
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        SongSelectionView(songs: summaries, onClose: {
            DispatchQueue.main.async {
                withAnimation {
                    appModel.closeSongSelection()
                    appModel.selectedChapter = nil
                    appState = .chapterSelect
                }
            }
        }, onChoose: { songSummary, difficulty in
            appModel.selectedSheetFilename = songSummary.id
            appModel.selectedDifficulty = difficulty
            appModel.closeSongSelection()
            DispatchQueue.main.async { withAnimation { appState = .playing } }
        })
    }
}

// Helper extension for PlayRecord date formatting (if PlayRecord has date property)
private extension PlayRecord {
    var dateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}

