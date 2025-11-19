//
//  HistoryUIViews.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//
//
// HistoryUIViews.swift
// Thumbnail button, record detail, and list used by ContentView
//

import SwiftUI

// Thumbnail button used in the history carousel/list.
// Keep this file-scope (outside ContentView) to avoid nested-type access issues.
public struct HistoryThumbnailButton: View {
    public let record: PlayRecord
    public let thumbnail: UIImage?
    public var onTap: () -> Void

    public init(record: PlayRecord, thumbnail: UIImage?, onTap: @escaping () -> Void) {
        self.record = record
        self.thumbnail = thumbnail
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                if let ui = thumbnail {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.18))
                }

                VStack {
                    HStack {
                        Spacer()
                        Text("C \(record.maxCombo)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(6)
                            .padding(6)
                    }
                    Spacer()
                }
            }
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.28), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Detail modal for a PlayRecord
public struct PlayRecordDetailView: View {
    public let record: PlayRecord
    public var onPreview: ((PlayRecord) -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode

    public init(record: PlayRecord, onPreview: ((PlayRecord) -> Void)? = nil) {
        self.record = record
        self.onPreview = onPreview
    }

    public var body: some View {
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
}

// Simple list view for history (used when opening history as a list)
public struct HistoryListView: View {
    public let records: [PlayRecord]
    public var onSelect: ((PlayRecord) -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode

    public init(records: [PlayRecord], onSelect: ((PlayRecord) -> Void)? = nil) {
        self.records = records
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationView {
            List(records) { r in
                HStack {
                    VStack(alignment: .leading) {
                        Text(r.sheetTitle ?? "Unknown").bold()
                        Text(r.date, style: .date).font(.caption)
                    }
                    Spacer()
                    Text("C \(r.maxCombo)").bold()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect?(r)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationBarTitle("Play History", displayMode: .inline)
        }
    }
}
