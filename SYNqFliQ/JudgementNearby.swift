//
//  NearbyJudgement.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/02.
//


import SwiftUI

// Small model used to represent a transient judgement shown near a note.
struct NearbyJudgement: Identifiable, Equatable {
    let id: UUID
    let text: String
    let color: Color
    let position: CGPoint
    let createdAt: Date
    let duration: TimeInterval
    static func == (lhs: NearbyJudgement, rhs: NearbyJudgement) -> Bool {
        return lhs.id == rhs.id
    }
}

// A small view that renders a judgement label at a given canvas position.
// You can customize fonts/offsets/animations as desired.
struct NearbyJudgementView: View {
    let j: NearbyJudgement
    var body: some View {
        Text(j.text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.65))
            .foregroundColor(j.color)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 3)
    }
}