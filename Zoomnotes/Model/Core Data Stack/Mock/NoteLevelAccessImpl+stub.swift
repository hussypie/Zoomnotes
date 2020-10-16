//
//  NoteLevelAccessImpl+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 29..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import Combine

extension NoteLevelAccessImpl {
    func stubP(with description: NoteLevelDescription) -> AnyPublisher<Self, Error> {
        return access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).flatMap { rect in
            return self.access.build(id: description.id, prepare: { (entity: NoteLevelStore) -> NoteLevelStore in
                entity.preview = description.preview.pngData()!
                entity.frame = rect
                entity.drawing = description.drawing.dataRepresentation()

                return entity
            })
        }.flatMap { _ in
            Publishers.Zip(
                Publishers.Sequence(sequence: description.sublevels)
                    .flatMap { sublevel in self.append(level: sublevel, to: description.id) }
                    .collect(),
                Publishers.Sequence(sequence: description.images)
                    .flatMap { image in self.append(image: image, to: description.id) }
                    .collect()
            )}
            .map { _ in self }
            .eraseToAnyPublisher()
    }

    func stub(with description: NoteLevelDescription) -> NoteLevelAccessImpl {
        let cancellable = access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).flatMap { rect in
            return self.access.build(id: description.id, prepare: { (entity: NoteLevelStore) -> NoteLevelStore in
                entity.preview = description.preview.pngData()!
                entity.frame = rect
                entity.drawing = description.drawing.dataRepresentation()

                return entity
            })
        }.flatMap { _ in
            Publishers.Zip(
                Publishers.Sequence(sequence: description.sublevels)
                    .flatMap { sublevel in self.append(level: sublevel, to: description.id) }
                    .collect(),
                Publishers.Sequence(sequence: description.images)
                    .flatMap { image in self.append(image: image, to: description.id) }
                    .collect()
            )
        }

        return self
    }
}
