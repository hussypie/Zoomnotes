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

    static var stub: DocumentStoreDescription {
        let thumbnail = stubImages.randomElement()!
        let rootLevel = NoteLevelDescription(preview: thumbnail,
                                             frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        return DocumentStoreDescription(id: ID(UUID()),
                                        lastModified: Date(),
                                        name: stubNames.randomElement()!,
                                        thumbnail: thumbnail,
                                        imageDrawer: [],
                                        levelDrawer: [],
                                        imageTrash: [],
                                        levelTrash: [],
                                        root: rootLevel)
    }
}
