//
//  SheetEditorView.swift
//  rhythm
//
//  Created by Karen Naito on 2025/11/15.
//

import SwiftUI

struct SheetEditorView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                Text("Sheet Editor - stub")
                    .padding()
                Text("This is a minimal placeholder for SheetEditorView.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .navigationBarTitle("Editor", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#if DEBUG
struct SheetEditorView_Previews: PreviewProvider {
    static var previews: some View {
        SheetEditorView()
    }
}
#endif
