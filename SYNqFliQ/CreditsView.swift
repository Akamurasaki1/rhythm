//
//  CreditsView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/28.
//
import SwiftUI
struct CreditsView: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .center) {
                Text("LeaF").font(.title3.bold())
            }
            VStack(alignment: .leading){
                Divider()
                Text("0次元恋愛感情").foregroundColor(.secondary)
                Text("BPM:")
                Divider()
                Text("4th_smile").foregroundColor(.secondary)
                Text("Agilion").foregroundColor(.secondary)
                Text("Aleph-0").foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label("LeaF's Page", systemImage: "link")
                        .font(.footnote).foregroundColor(.blue)
                }
            }
        }.border(Color(.red), width: 1)
        HStack(alignment: .center) {
            VStack(alignment: .center) {
                Text("Camellia").font(.title3.bold())
            }
            VStack(alignment: .leading){
                Text("+ERABY+E CONNEC+10N").foregroundColor(.secondary)
                Text("Flamewall").foregroundColor(.secondary)
                Text("Tera I_O").foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label("Camellia's Page", systemImage: "link")
                        .font(.footnote).foregroundColor(.blue)
                }
            }
        }
    }
}

