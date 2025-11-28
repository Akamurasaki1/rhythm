//
//  HistoryScreen.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/26.
//


//
//  HistoryScreen.swift
//  SYNqFliQ
//
//  Lightweight history list + detail view.
//  - Tap a row to see the PlayRecord detail.
//  - From the detail you can press "Play" to request the app play that record's sheet/difficulty.
//
//  Usage (example):
//    HistoryScreen(onClose: { /* back to title */ },
//                  onPlayRecord: { rec in
//                      appModel.selectedSheetFilename = rec.sheetFilename
//                      appModel.selectedDifficulty = rec.difficulty // if PlayRecord has this field
//                      appState = .playing
//                  })
//  Place this file in your project and import where needed.
//

import SwiftUI

// NOTE: This file expects PlayRecord and PlayHistoryStorage to already exist in your project.
// PlayRecord must conform to Identifiable and include at least:
//   var id: UUID { get }
//   var date: Date
//   var sheetFilename: String?
//   var sheetTitle: String?
//   var score: Int
//   var maxCombo: Int
// Optionally a 'difficulty' and 'level' field (if your PlayRecord stores them) will be respected.

struct HistoryScreen: View {
    var onClose: () -> Void
    
    /// Called when the user taps "Play" on a record detail.
    var onPlayRecord: (PlayRecord) -> Void

    @State private var records: [PlayRecord] = []
    @Environment(\.dismiss) private var dismiss
    var onBackToTitle: (() -> Void)? = nil
    var body: some View {
        NavigationView {
            Group {
                if records.isEmpty {
                    VStack {
                        Spacer()
                        Text("No history")
                            .foregroundColor(.secondary)
                            .font(.body)
                        Spacer()
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onClose()
                            }
                        }) {
                            Text("閉じる")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    List {
                        ForEach(records) { rec in
                            NavigationLink(destination: PlayRecordDetailView(record: rec)) {
                                HistoryRowView(record: rec)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
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

private struct HistoryRowView: View {
    let record: PlayRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.sheetTitle ?? record.sheetFilename ?? "Unknown")
                    .font(.body)
                    .lineLimit(1)
                Text("\(record.score) pts • \(record.maxCombo) combo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(record.dateFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

/// Detail view that shows full stats for a PlayRecord and offers Play / Share / Close actions.
public struct PlayRecordDetailView: View {
    public let record: PlayRecord
    public var onPreview: ((PlayRecord) -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode

    public init(record: PlayRecord, onPreview: ((PlayRecord) -> Void)? = nil) {
        self.record = record
        self.onPreview = onPreview
    }

    public var body: some View {
     /*   VStack(spacing: 8) {
            Text("This is HistoryUIView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        } */
        NavigationView {
            VStack(spacing: 16) {
                Text(record.sheetTitle ?? "Unknown")
                    .font(.title2)
                    .bold()
                Text(record.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    VStack { Text("Score"); Text("\(record.score)") }
                    VStack { Text("Max Combo"); Text("\(record.maxCombo)") }
                    VStack { Text("Perfect"); Text("\(record.perfectCount)") }
                }
                .font(.headline)
                .padding()

                Spacer()

                HStack {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)

                    Spacer()

                    Button(action: {
                        onPreview?(record)
                    }) {
                        Text("Preview")
                            .bold()
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitle("Play Detail", displayMode: .inline)
        }
    }



    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
    }

    private func shareText() -> String {
        var s = "SYNqFliQ Result\n"
        s += "\(record.sheetTitle ?? record.sheetFilename ?? "Unknown")\n"
        s += "Score: \(record.score)\n"
        s += "Max Combo: \(record.maxCombo)\n"
        if let diff = record.difficulty { s += "Difficulty: \(diff)\n" }
        if let level = record.level { s += "Level: \(level)\n" }
        s += "Date: \(record.dateFormatted)\n"
        return s
    }
}

// Small convenience extension used above (keeps formatting within this file)
private extension PlayRecord {
    var dateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}
