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
    static func stubP(
        using access: DBAccess,
        with document: DocumentStoreDescription
    ) -> AnyPublisher<NoteLevelAccessImpl, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in // build root rect
            store.x = Float(document.root.frame.minX)
            store.y = Float(document.root.frame.minY)
            store.width = Float(document.root.frame.width)
            store.height = Float(document.root.frame.height)

            return store
        }).flatMap { rootRect in // build root level
            return access.build(id: document.root.id, prepare: { (level: NoteLevelStore) -> NoteLevelStore in
                level.drawing = document.root.drawing.dataRepresentation()
                level.preview = document.root.preview.pngData()!
                level.frame = rootRect
                level.sublevels = NSSet()
                level.images = NSSet()

                return level
            })
        }.flatMap { rootLevel in // build document
            access.build(id: document.id, prepare: { (doc: NoteStore) -> NoteStore in
                doc.thumbnail = document.thumbnail.pngData()!
                doc.lastModified = document.lastModified
                doc.name = document.name
                doc.root = rootLevel

                return doc
            })
        }.map { _ in
            NoteLevelAccessImpl(access: access, document: document.id)
        }.flatMap { (noteAccess: NoteLevelAccessImpl) -> AnyPublisher<NoteLevelAccessImpl, Error> in
            Publishers.Zip(
                Publishers.Sequence(sequence: document.root.sublevels)
                    .flatMap { sublevel in noteAccess.append(level: sublevel, to: document.root.id) }
                    .collect(),
                Publishers.Sequence(sequence: document.root.images)
                    .flatMap { image in noteAccess.append(image: image, to: document.root.id) }
                    .collect()
                ).map { _ in noteAccess }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
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
