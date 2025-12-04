//
//  StoriesView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/12/04.
//

import SwiftUI

struct StoriesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("This is StoriesView")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
        }
        Text("Tutorial View")
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .onTapGesture(perform: onClose ?? { })
    }
    
    // Called when the user presses Start
    var onClose: (() -> Void)?
}
