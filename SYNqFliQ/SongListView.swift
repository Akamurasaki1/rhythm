import SwiftUI
import Combine


import FirebaseAuth

/// SongListView with automatic initial loading overlay:
/// - On appear it triggers ScoreStore.shared.refresh(for: currentUser) and shows LoadingOverlay
///   until userSheets changes (or a small timeout).
/// - Also preserves Play button behavior (shows loading for playback).
struct SongListView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isLoading: Bool = false
    @State private var loadingProgress: Double? = nil
    @State private var hideWork: DispatchWorkItem?
    @State private var cancellable: AnyCancellable?
    @State private var initialLoadCancellable: AnyCancellable?
    @State private var didInitialRefresh = false

    // Combine bundled + user sheets into a simple summary model
    struct Summary: Identifiable {
        let id: String
        let title: String
        let composer: String?
        let thumbnailFilename: String?
        let isBundled: Bool
        let bundledIndex: Int?
    }

    private var summaries: [Summary] {
        var out: [Summary] = []
        for (i, b) in appModel.bundledSheets.enumerated() {
            out.append(Summary(id: b.filename, title: b.sheet.title, composer: b.sheet.composer, thumbnailFilename: b.sheet.thumbnailFilename, isBundled: true, bundledIndex: i))
        }
        for u in ScoreStore.shared.userSheets {
            out.append(Summary(id: u.id ?? UUID().uuidString, title: u.title, composer: u.composer, thumbnailFilename: u.thumbnailFilename, isBundled: false, bundledIndex: nil))
        }
        return out
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(summaries) { s in
                    HStack(spacing: 12) {
                        SongThumbnailView(filename: s.thumbnailFilename)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading) {
                            Text(s.title)
                                .font(.headline)
                            if let c = s.composer { Text(c).font(.subheadline).foregroundColor(.secondary) }
                        }
                        Spacer()
                        Button(action: {
                            playSummary(s)
                        }) {
                            Text("Play")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Songs")
            .overlay(LoadingOverlay(isPresented: $isLoading, progress: loadingProgress))
            .onReceive(NotificationCenter.default.publisher(for: .playbackDidStart)) { _ in
                // hide playback loading when playback starts
                self.isLoading = false
                self.loadingProgress = nil
                self.hideWork?.cancel()
                self.hideWork = nil
            }
            .onAppear {
                // If we haven't done the initial refresh for the current user, do it now
                guard !didInitialRefresh else { return }
                didInitialRefresh = true

                let uid = AuthManager.shared.firebaseUser?.uid ?? "local-user"
                // show loading overlay while ScoreStore loads user sheets
                self.isLoading = true
                self.loadingProgress = nil

                // Subscribe to changes on userSheets and hide overlay once the array updates.
                // We keep a short timeout as a fallback to avoid indefinite spinner.
                self.initialLoadCancellable = ScoreStore.shared.$userSheets
                    .receive(on: DispatchQueue.main)
                    .sink { sheets in
                        // When refresh completes, userSheets will be updated (possibly empty).
                        // We hide the overlay after seeing the first update.
                        self.isLoading = false
                        self.initialLoadCancellable?.cancel()
                        self.initialLoadCancellable = nil
                    }

                // Trigger refresh (ScoreStore.refresh runs async)
                ScoreStore.shared.refresh(for: uid)

                // Fallback: hide overlay after 4 seconds if nothing changed
                let fallback = DispatchWorkItem {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.initialLoadCancellable?.cancel()
                        self.initialLoadCancellable = nil
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: fallback)
            }
            .onDisappear {
                // Cancel any pending initial subscription when leaving the view
                self.initialLoadCancellable?.cancel()
                self.initialLoadCancellable = nil
            }
        }
    }

    private func playSummary(_ s: Summary) {
        let uid = AuthManager.shared.firebaseUser?.uid ?? "local-user"

        // show loading overlay for playback
        self.isLoading = true
        self.loadingProgress = nil

        // post a pre-start notification so other components can show loading too
        NotificationCenter.default.post(name: .playbackWillStart, object: nil, userInfo: ["sheetID": s.id, "userID": uid])

        // post actual play request — existing flow will start playback
        NotificationCenter.default.post(name: .playSheet, object: nil, userInfo: ["sheetID": s.id, "userID": uid])

        // Fallback: if playbackDidStart is not received within 6s, hide overlay
        hideWork?.cancel()
        let work = DispatchWorkItem {
            DispatchQueue.main.async {
                withAnimation { self.isLoading = false; self.loadingProgress = nil }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: work)
    }
}

/// Small helper to load thumbnail image either from bundle or user-saved assets.
private struct SongThumbnailView: View {
    var filename: String?

    var body: some View {
        if let url = thumbnailURL(for: filename) {
            if let ui = UIImage(contentsOfFile: url.path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Color.gray
            }
        } else {
            Image(systemName: "music.note")
                .resizable()
                .scaledToFit()
                .padding(12)
                .foregroundColor(.white)
                .background(Color.gray)
        }
    }

    private func thumbnailURL(for filename: String?) -> URL? {
        guard let fn = filename, !fn.isEmpty else { return nil }
        let uid = AuthManager.shared.firebaseUser?.uid ?? "local-user"
        if let s = ScoreStore.shared.userSheets.first(where: { $0.thumbnailFilename == fn }), let url = ScoreStore.shared.thumbnailURL(for: s, userID: uid) {
            return url
        }
        let ext = (fn as NSString).pathExtension
        let name = (fn as NSString).deletingPathExtension
        if let u = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext) {
            return u
        }
        return nil
    }
}
