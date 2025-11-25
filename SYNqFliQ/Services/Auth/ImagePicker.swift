//
//  ImagePicker.swift
//  SYNqFliQ
//
//  Created by Karen Naito on 2025/11/23.
//


import SwiftUI
import PhotosUI

public struct ImagePicker: UIViewControllerRepresentable {
    @Binding public var image: UIImage?
    public init(image: Binding<UIImage?>) {
        self._image = image
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first else { return }
            if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
                item.itemProvider.loadObject(ofClass: UIImage.self) { (obj, err) in
                    DispatchQueue.main.async {
                        if let ui = obj as? UIImage {
                            self.parent.image = ui
                        }
                    }
                }
            }
        }
    }
}