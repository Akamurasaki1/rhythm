//
//  TutorialView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/20.
//

import SwiftUI

struct TutorialView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("This is TutorialView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        }
        Text("Tutorial View")
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .onTapGesture(perform: onStart ?? { })
    }
    
    // Called when the user presses Start
    var onStart: (() -> Void)?
}
