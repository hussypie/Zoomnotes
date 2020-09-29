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
        let rect = try! StoreBuilder<RectStore>(prepare: { store in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).build(using: self.moc)

        // swiftlint:disable:next force_try
        _ = try! StoreBuilder<NoteLevelStore>(prepare: { entity in
            entity.id = description.id
            entity.preview = description.preview.pngData()!
            entity.frame = rect
            entity.drawing = description.drawing.dataRepresentation()

            return entity
        }).build(using: self.moc)

        for sublevel in description.sublevels {
            // swiftlint:disable:next force_try
            try! self.append(level: sublevel, to: description.id)
        }

        return self
    }
}
