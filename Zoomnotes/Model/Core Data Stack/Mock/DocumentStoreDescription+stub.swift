//
//  DocumentStoreDescription+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

extension DocumentStoreDescription {
    private static let stubImages: [UIImage] = [.actions, .checkmark, .remove, .add]
    private static let stubNames: [String] = ["Cats", "Dogs", "Unit tests"]

    static func stub(data: String) -> DocumentStoreDescription {
        let thumbnail = stubImages.randomElement()!
        let rootLevel = NoteLevelDescription(parent: nil,
                                             preview: thumbnail.pngData()!,
                                             frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [])

        return DocumentStoreDescription(id: UUID(),
                                        lastModified: Date(),
                                        name: stubNames.randomElement()!,
                                        thumbnail: thumbnail,
                                        root: rootLevel)
    }
}
