//
//  TutorialView.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/20.
//

import SwiftUI

struct TutorialView: View {
    var body: some View {
        Text("Tutorial View")
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .onTapGesture(perform: onStart ?? { })
    }
    
    // Called when the user presses Start
    var onStart: (() -> Void)?
}
