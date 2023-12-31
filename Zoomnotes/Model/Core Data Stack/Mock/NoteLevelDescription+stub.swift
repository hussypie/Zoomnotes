//
//  NoteLevelDescription+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit
import UIKit

extension NoteLevelDescription {
    static func stub(parent: UUID?) -> NoteLevelDescription {
        return NoteLevelDescription(preview: UIImage.checkmark,
                                    frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
                                    id: ID(UUID()),
                                    drawing: PKDrawing(),
                                    sublevels: [],
                                    images: [])
    }
}
