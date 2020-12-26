//
//  ImageDetailViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 07..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine
import PencilKit

class ImageDetailViewModel: ObservableObject {
    @Published var image: UIImage
    @Published var drawing: PKDrawing

    fileprivate(set) var previewChanged = PassthroughSubject<UIImage, Never>()

    init(using image: UIImage, with annotation: PKDrawing) {
        self.image = image
        self.drawing = annotation
    }

    func setImage(image: UIImage) {
        self.image = image
    }

    func setDrawing(drawing: PKDrawing) {
        self.drawing = drawing
    }
}
