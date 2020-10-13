//
//  NoteLevelAccessImpl+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 29..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

extension NoteLevelAccessImpl {
    func stub(with description: NoteLevelDescription) -> NoteLevelAccessImpl {
        // swiftlint:disable:next force_try
        let rect = try! access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        })

        // swiftlint:disable:next force_try
        _ = try! access.build(id: description.id, prepare: { (entity: NoteLevelStore) -> NoteLevelStore in
            entity.preview = description.preview.pngData()!
            entity.frame = rect
            entity.drawing = description.drawing.dataRepresentation()

            return entity
        })

        for sublevel in description.sublevels {
            // swiftlint:disable:next force_try
            try! self.append(level: sublevel, to: description.id)
        }

        for image in description.images {
            // swiftlint:disable:next force_try
            try! self.append(image: image, to: description.id)
        }

        return self
    }
}
