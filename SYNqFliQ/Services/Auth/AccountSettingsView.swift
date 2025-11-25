//
//  AccountSettingsView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/23.
//

import SwiftUI
import PhotosUI

public struct AccountSettingsView: View {
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var firestore = FirestoreManager.shared

    @State private var displayName: String = ""
    @State private var showRankToggle: Bool = true
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var uiImage: Image? = nil
    @State private var isSaving = false
    @Environment(\.presentationMode) var presentationMode

    // Alert 用ラッパー（Identifiable にする）
    private struct AlertItem: Identifiable {
        let id = UUID()
        let message: String
    }
    @State private var alertItem: AlertItem? = nil

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // profile image
                ZStack {
                    if let uiImage = uiImage {
                        uiImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .foregroundColor(.gray)
                    }
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        .frame(width: 110, height: 110)
                }
                Button("Change Photo") {
                    showingImagePicker = true
                }

                // display name
                VStack(alignment: .leading) {
                    Text("Display name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Nickname", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // show rank toggle
                Toggle(isOn: $showRankToggle) {
                    Text("Show rank publicly")
                }

                Spacer()

                if isSaving {
                    ProgressView("Saving...")
                }

                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                    }
                    Spacer()
                    Button(action: save) {
                        Text("Save")
                            .bold()
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadInitial)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .alert(item: $alertItem) { item in
                Alert(title: Text("Error"), message: Text(item.message), dismissButton: .default(Text("OK")))
            }
            .onChange(of: selectedImage) { new in
                if let s = new {
                    uiImage = Image(uiImage: s)
                }
            }
        }
    }

    private func loadInitial() {
        displayName = firestore.profile?.displayName ?? ""
        showRankToggle = firestore.showRank
        // load from iconBase64 if present (we stored it into profile.iconURL as data:... earlier)
        if let icon = firestore.profile?.iconURL, icon.starts(with: "data:image") {
            // icon is data URI including base64
            if let b64 = icon.split(separator: ",").last,
               let data = Data(base64Encoded: String(b64)),
               let ui = UIImage(data: data) {
                selectedImage = ui
                uiImage = Image(uiImage: ui)
            }
        } else if let urlStr = firestore.profile?.iconURL, let url = URL(string: urlStr) {
            // fallback: load remote URL if present
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let d = data, let ui = UIImage(data: d) {
                    DispatchQueue.main.async {
                        selectedImage = ui
                        uiImage = Image(uiImage: ui)
                    }
                }
            }.resume()
        }
    }

    private func save() {
        isSaving = true
        // If a new image is selected, upload as base64 and then save display name + settings
        func finish(_ err: Error?) {
            DispatchQueue.main.async {
                isSaving = false
                if let e = err {
                    alertItem = AlertItem(message: e.localizedDescription)
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }

        if let img = selectedImage {
            firestore.uploadProfileImageAsBase64(img) { res in
                switch res {
                case .success:
                    firestore.saveProfileDisplayName(displayName: displayName.isEmpty ? nil : displayName) { err in
                        firestore.setShowRank(showRankToggle) { _ in
                            finish(err)
                        }
                    }
                case .failure(let err):
                    finish(err)
                }
            }
        } else {
            // image unchanged
            firestore.saveProfileDisplayName(displayName: displayName.isEmpty ? nil : displayName) { err in
                firestore.setShowRank(showRankToggle) { _ in
                    finish(err)
                }
            }
        }
    }
}
