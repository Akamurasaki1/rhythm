//
//  HistoryUIViews.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/18.
//
import SwiftUI

// small thumbnail button for a PlayRecord
struct HistoryThumbnailButton: View {
    let record: PlayRecord
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // try to show sheet thumbnail or background if available via bundle lookup
                if let filename = record.sheetFilename {
                    // attempt to find image by filename without extension first via bundleURLForMedia or UIImage(named:)
                    if let url = Bundle.main.url(forResource: (filename as NSString).deletingPathExtension, withExtension: "png", subdirectory: "bundled-backgrounds"),
                       let data = try? Data(contentsOf: url),
                       let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else if let img = UIImage(named: (record.sheetTitle ?? "")) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        // fallback colored box
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }

                // small overlay: maxCombo / score
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("C:\(record.maxCombo)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.45))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(6)
            }
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// detail modal for a record (shows stats and preview action)
struct PlayRecordDetailView: View {
    let record: PlayRecord
    var onPreview: ((PlayRecord)->Void)? = nil
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(record.sheetTitle ?? "Unknown")
                    .font(.title2)
                    .bold()
                Text(record.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    VStack {
                        Text("Score"); Text("\(record.score)")
                    }
                    VStack {
                        Text("Max Combo"); Text("\(record.maxCombo)")
                    }
                    VStack {
                        Text("Perfect"); Text("\(record.perfectCount)")
                    }
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
                        presentationMode.wrappedValue.dismiss()
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
