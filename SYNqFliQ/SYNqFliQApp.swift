//
//  SYNqFliQApp.swift
//  SYNqFliQ
//
//  Updated: added .History handling and a lightweight HistoryScreen.
//  Place in your project replacing the existing SYNqFliQApp.swift (or merge changes).
//
import SwiftUI
import FirebaseCore

@main
struct SYNqFliQApp: App {
    init() {
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("DBG: Firebase configured")
        }
    }

    enum AppState { case title, songSelect, playing, tutorial, history,chapterSelect }

    @StateObject private var appModel = AppModel()
    @StateObject private var settings = SettingsStore()
    @State private var appState: AppState = .title
    @State private var showingSettings: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                // honor explicit song-selection request first
                if appModel.showingSongSelection {
                    songSelectionView()
                        .environmentObject(appModel)
                        .environmentObject(settings)
                } else {
                    switch appState {
                    case .title:
                        // pass onShowHistories closure to TitleView
                        // SYNqFliQApp.swift — inside case .title:
                        TitleView(
                            onStart: {
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut) { appState = .songSelect }
                                }
                            },
                            onOpenSettings: {
                                showingSettings = true
                            },
                            onShowCredits: {
                                // handle credits
                            },
                            onShowTutorial: {
                                DispatchQueue.main.async { withAnimation(.easeInOut) { appState = .tutorial } }
                            },
                            onShowHistories: {
                                DispatchQueue.main.async { withAnimation(.easeInOut) { appState = .history } }
                            },
                            onShowChapters: {
                                DispatchQueue.main.async { withAnimation { appState = .chapterSelect } }
                            }
                        )
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

                    case .history:
                        HistoryScreen(onClose: {
                            withAnimation { appState = .title }
                        }, onPlayRecord: { rec in
                            // set selection (use fields available on PlayRecord)
                            appModel.selectedSheetFilename = rec.sheetFilename
                            // if your PlayRecord stores difficulty/level, restore it:
                            appModel.selectedDifficulty = rec.difficulty
                            // close selection UI and switch to playing state
                            appModel.closeSongSelection()
                            DispatchQueue.main.async { withAnimation { appState = .playing } }
                        })
                        .environmentObject(appModel)
                        .environmentObject(settings)
                        
                    // case .chapterSelect: の扱い（App の body の switch に追加）
                        // Replace your existing `case .chapterSelect:` block with this
                    case .chapterSelect:
                        chapterSelectionView()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(settings)
            }
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
        // prepare chapter list (example static list; replace with real data)
        let chapters = [
            Chapter(id: "all", title: "All Songs", subtitle: "Browse every song"),
            Chapter(id: "LeaF", title: "LeaF", subtitle: "LeaF songs",thumbnailFilename:"LeaF_t.png"),
            Chapter(id: "Akamurasaki", title: "Akamurasaki", subtitle: "Akamurasaki songs",thumbnailFilename:"Akamurasaki_t.jpg"),
            Chapter(id: "special", title: "Special", subtitle: "Event tracks")
        ]

        ChapterSelectionView(chapters: chapters, onSelect: { ch in
            appModel.selectedChapter = ch.id   // make sure AppModel has this property
            DispatchQueue.main.async {
                withAnimation { appState = .songSelect }
            }
        }, onClose: {
            DispatchQueue.main.async { withAnimation { appState = .title } }
        })
        .environmentObject(appModel)
        .environmentObject(settings)
    }
    // existing songSelectionView() implementation (kept as before)
    @ViewBuilder
    private func songSelectionView() -> some View {
        // entries: [(index: Int, entry: BundledSheet)]
        let entries = appModel.bundledSheets.enumerated().map { (index: $0.offset, entry: $0.element) }

        // Apply chapter filter if selected.
        // Use the same element type as `entries` (BundleSheet) so the types match.
        let filteredEntries: [(index: Int, entry: BundledSheet)] = {
            guard let ch = appModel.selectedChapter, !ch.isEmpty, ch != "all" else {
                return entries
            }
            return entries.filter { pair in
                // safe optional access: if pair.entry.sheet.chapter is nil, treat as "all"
                return (pair.entry.sheet.chapter ?? "all") == ch
            }
        }()

        // group by title (or whatever your existing logic is)
        let groupedByTitle = Dictionary(grouping: filteredEntries, by: { $0.entry.sheet.title })
        let summaries: [SongSelectionView.SongSummary] = groupedByTitle.map { (_, list) in
            let representative = list[0]
            return SongSelectionView.SongSummary(
                id: representative.entry.filename,
                title: representative.entry.sheet.title,
                thumbnailFilename: representative.entry.sheet.thumbnailFilename ?? representative.entry.sheet.backgroundFilename,
                bundledIndex: representative.index
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        SongSelectionView(songs: summaries, onClose: {
            DispatchQueue.main.async {
                withAnimation {
                    appModel.closeSongSelection()
                    appModel.selectedChapter = nil // clear filter if desired
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
/*
// Lightweight history screen used by the App state.
// If you already have a HistoryListView / PlayRecord model, you can swap it here.
private struct HistoryScreen: View {
    var onClose: () -> Void
    var onSelectRecord: (PlayRecord) -> Void

    @State private var records: [PlayRecord] = []

    var body: some View {
        NavigationView {
            List {
                if records.isEmpty {
                    Text("No history").foregroundColor(.secondary)
                } else {
                    ForEach(records) { rec in
                        Button(action: { onSelectRecord(rec) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(rec.sheetTitle ?? rec.sheetFilename ?? "Unknown")
                                        .font(.body)
                                    Text("\(rec.score) pts • \(rec.maxCombo) combo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(rec.dateFormatted)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Play History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { onClose() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        records = PlayHistoryStorage.load()
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
*/
