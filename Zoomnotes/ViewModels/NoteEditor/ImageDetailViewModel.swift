//
//  ImageDetailViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 07..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

class ImageDetailViewModel {
    let image: UIImage
    let drawing: PKDrawing

    init(using image: UIImage, with annotation: PKDrawing) {
        self.image = image
        self.drawing = annotation
    }
}
