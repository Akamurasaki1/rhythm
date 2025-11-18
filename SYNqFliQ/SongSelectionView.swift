//
//  SongSelectionView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//  Revised by assistant for compile / isolation and crash fix
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit
import AVKit

struct SongSelectionView: View {
    // Public API: provide list of songs to show and callbacks
    struct SongSummary: Identifiable, Equatable {
        let id: String        // e.g. sheet.id or filename
        let title: String
        let thumbnailFilename: String? // optional image name in bundle / Documents
        let bundledIndex: Int? // optional source index
    }

    var songs: [SongSummary] = []
    var onClose: () -> Void = { }
    // When a song is chosen, we call onChoose(song, difficulty)
    var onChoose: (SongSummary, String) -> Void = { _, _ in }

    init(songs: [SongSummary] = [], onClose: @escaping () -> Void = {}, onChoose: @escaping (SongSummary, String) -> Void = { _, _ in }) {
        self.songs = songs
        self.onClose = onClose
        self.onChoose = onChoose
    }

    var body: some View {
        SongSelectView(songs: songs, onChoose: onChoose, onCancel: onClose)
    }

    // MARK: - Inner View
    struct SongSelectView: View {
        var songs: [SongSummary]
        var onChoose: (SongSummary, String) -> Void
        var onCancel: () -> Void

        // UI state
        @State private var focusedIndex: Int? = nil
        @State private var showDifficulty: Bool = false
        @State private var dragOffsetY: CGFloat = 0.0
        @GestureState private var isDetectingLongPress = false

        // carousel internal
        @State private var initialScrollPerformed: Bool = false
        @State private var selectedIndex: Int = 0

        // appearance
        private let carouselItemWidth: CGFloat = 100
        private let carouselItemSpacing: CGFloat = 12
        private let tileSize = CGSize(width: 160, height: 96)
        private let spacing: CGFloat = 18.0

        var body: some View {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack {
                        Spacer().frame(height: 24)

                        Text("Select Song")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)

                        ZStack {
                            carouselView(size: geo.size)
                                .frame(height: 220)
                                .clipped()
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 6, coordinateSpace: .local)
                                .onChanged { value in
                                    if focusedIndex != nil {
                                        dragOffsetY = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if focusedIndex != nil {
                                        if value.translation.height > 120 || value.predictedEndTranslation.height > 150 {
                                            withAnimation(.easeOut) {
                                                closeFocus()
                                                onCancelIfNeeded()
                                            }
                                        } else {
                                            withAnimation(.spring()) {
                                                dragOffsetY = 0
                                            }
                                        }
                                    }
                                }
                        )

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(1)

                    if let fi = focusedIndex, songs.indices.contains(fi) {
                        let song = songs[fi]
                        VStack(spacing: 16) {
                            tileView(for: song)
                                .frame(width: tileSize.width*1.12, height: tileSize.height*1.12)
                                .shadow(radius: 12)
                                .offset(y: min(dragOffsetY, 200))
                                .transition(.move(edge: .bottom).combined(with: .scale))
                                .zIndex(10)

                            if showDifficulty {
                                HStack(spacing: 18) {
                                    difficultyButton("Easy") { choose(song: song, difficulty: "Easy") }
                                    difficultyButton("Normal") { choose(song: song, difficulty: "Normal") }
                                    difficultyButton("Hard") { choose(song: song, difficulty: "Hard") }
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .zIndex(9)
                            } else {
                                Text("Swipe down to go back")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 6)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                showDifficulty.toggle()
                            }
                        }
                        .zIndex(8)
                        .transition(.opacity)
                    }

                    VStack {
                        HStack {
                            Button(action: {
                                if focusedIndex != nil {
                                    withAnimation(.easeOut) { closeFocus() }
                                } else {
                                    onCancel()
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .padding()
                        Spacer()
                    }
                    .zIndex(20)
                }
            }
        }

        // MARK: - Carousel
        @ViewBuilder
        private func carouselView(size: CGSize) -> some View {
            // If there are no songs, show a safe placeholder instead of attempting to index songs[0]
            if songs.isEmpty {
                VStack {
                    Spacer()
                    Text("No songs available")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("empty_placeholder")
            } else {
                let entriesCount = songs.count
                let initialIndex = max(0, entriesCount / 2)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: carouselItemSpacing) {
                            ForEach(songs.indices, id: \.self) { i in
                                GeometryReader { itemGeo in
                                    let frame = itemGeo.frame(in: .global)
                                    let centerX = UIScreen.main.bounds.width / 2
                                    let midX = frame.midX
                                    let diff = midX - centerX
                                    let normalized = max(-1.0, min(1.0, diff / (size.width * 0.5)))
                                    let rotateDeg = -normalized * 30.0
                                    let scale = 1.0 - abs(normalized) * 0.25
                                    let opacity = 1.0 - abs(normalized) * 0.6
                                    let song = songs[i]

                                    VStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedIndex == i ? Color.blue : Color.gray.opacity(0.3))
                                                .frame(width: carouselItemWidth, height: 64)
                                                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                                            Text(song.title)
                                                .foregroundColor(.white)
                                                .bold()
                                        }
                                    }
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .rotation3DEffect(.degrees(rotateDeg), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedIndex = i
                                            // focus this tile
                                            focusedIndex = i
                                            showDifficulty = true
                                            // scroll to center
                                            proxy.scrollTo(i, anchor: .center)
                                        }
                                    }
                                }
                                .frame(width: carouselItemWidth, height: 80)
                                .id(i)
                            }
                        }
                        .padding(.horizontal, (UIScreen.main.bounds.width - carouselItemWidth) / 2 - carouselItemSpacing)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        if !initialScrollPerformed {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                proxy.scrollTo(initialIndex, anchor: .center)
                                initialScrollPerformed = true
                            }
                        }
                    }
                }
            }
        }

        // MARK: - tile view
        @ViewBuilder
        private func tileView(for song: SongSummary) -> some View {
            ZStack {
                if let imgName = song.thumbnailFilename, let uiurl = bundleImageURL(named: imgName), let data = try? Data(contentsOf: uiurl), let uiimg = UIImage(data: data) {
                    Image(uiImage: uiimg)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }

                VStack {
                    Spacer()
                    Text(song.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45))
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }
            }
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }

        // MARK: - difficulty button
        @ViewBuilder
        private func difficultyButton(_ text: String, action: @escaping ()->Void) -> some View {
            Button(action: action) {
                Text(text)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            }
        }

        // MARK: - helpers
        private func choose(song: SongSummary, difficulty: String) {
            onChoose(song, difficulty)
        }

        private func closeFocus() {
            focusedIndex = nil
            showDifficulty = false
            dragOffsetY = 0
        }

        private func onCancelIfNeeded() {
            if focusedIndex == nil {
                onCancel()
            }
        }

        // Simple bundle image lookup
        private func bundleImageURL(named imageFilename: String) -> URL? {
            guard !imageFilename.isEmpty else { return nil }
            let ext = (imageFilename as NSString).pathExtension
            let name = (imageFilename as NSString).deletingPathExtension

            if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext, subdirectory: "bundled-resources") {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext) {
                return url
            }
            let fm = FileManager.default
            if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                let candidate = docs.appendingPathComponent(imageFilename)
                if fm.fileExists(atPath: candidate.path) { return candidate }
            }
            return nil
        }

        // Minimal import handler (stub for later expansion)
        func handleImportedFile(url: URL) {
            DispatchQueue.global(qos: .userInitiated).async {
                var didStart = false
                if url.startAccessingSecurityScopedResource() {
                    didStart = true
                }
                defer {
                    if didStart { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    let fm = FileManager.default
                    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let dest = docs.appendingPathComponent(url.lastPathComponent)
                    if fm.fileExists(atPath: dest.path) {
                        // replace or skip as desired
                        try fm.removeItem(at: dest)
                    }
                    try fm.copyItem(at: url, to: dest)
                    print("DBG: imported file copied to Documents: \(dest)")
                } catch {
                    print("DBG: import failed: \(error)")
                }
            }
        }
    }
}
