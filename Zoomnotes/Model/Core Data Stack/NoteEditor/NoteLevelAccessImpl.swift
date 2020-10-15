//
//  NoteModelAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 19..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData
import PencilKit
import Combine
import UIKit

struct NoteLevelAccessImpl: NoteLevelAccess {
    let access: DBAccess

    enum AccessMode {
        case read
        case write
    }

    enum AccessError: Error {
        case cannotCreateRectStore
        case cannotCreateLevelStore
        case cannotCreateImageStore
    }

    func append(level description: NoteLevelDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in
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
        }.flatMap { sublevel in
            return self.access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) -> Void in
                guard let store = store else { throw AccessError.cannotCreateLevelStore }
                guard let sublevel = sublevel else { throw AccessError.cannotCreateLevelStore }
                store.addToSublevels(sublevel)
            }
        }.flatMap { _ in
            Publishers.Sequence(sequence: description.sublevels)
                .flatMap { sublevel in self.append(level: sublevel, to: description.id) }
                .collect()
        }.map { _ in return }.eraseToAnyPublisher()
    }

    func append(image description: NoteImageDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
       return access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).flatMap { rect in
            return self.access.build(id: description.id, prepare: { (store: ImageStore) -> ImageStore in
                store.frame = rect
                store.drawingAnnotation = description.drawing.dataRepresentation()
                store.image = description.image.pngData()!
                store.preview = description.image.pngData()!

                return store
            })
        }.flatMap { image in
            self.access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
                guard let store = store else { throw AccessError.cannotCreateImageStore }
                guard let image = image else { throw AccessError.cannotCreateImageStore }
                store.addToImages(image)
            }
       }.eraseToAnyPublisher()
    }

    func remove(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        return access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            guard let sublevels = store.sublevels as? Set<NoteLevelStore> else { return }
            guard let child = sublevels.first(where: { $0.id! == id }) else { return }

            store.removeFromSublevels(child)
            self.access.delete(child)
        }.eraseToAnyPublisher()
    }

    func remove(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            guard let images = store.images as? Set<ImageStore> else { return }
            guard let subject = images.first(where: { $0.id! == id }) else { return }

            store.removeFromImages(subject)
            self.access.delete(subject)
        }.eraseToAnyPublisher()
    }

    func read(level id: NoteLevelID) -> AnyPublisher<NoteLevelDescription?, Error> {
        access.accessing(to: .read, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return nil }

            return try NoteLevelDescription.from(store: store)
        }.eraseToAnyPublisher()
    }

    func read(image id: NoteImageID) -> AnyPublisher<NoteImageDescription?, Error> {
        access.accessing(to: .read, id: id) { (store: ImageStore?) in
            guard let store = store else { return nil }
            guard let preview = UIImage(data: store.preview!) else { return nil }
            guard let image = UIImage(data: store.image!) else { return nil }
            guard let drawing = try? PKDrawing(data: store.drawingAnnotation!) else { return nil }

            let frame = CGRect(x: CGFloat(store.frame!.x),
                               y: CGFloat(store.frame!.y),
                               width: CGFloat(store.frame!.width),
                               height: CGFloat(store.frame!.height))

            return NoteImageDescription(id: ID(store.id!),
                                        preview: preview,
                                        drawing: drawing,
                                        image: image,
                                        frame: frame)
        }
    }

    func update(drawing: PKDrawing, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.drawing = drawing.dataRepresentation()
        }
    }

    func update(annotation: PKDrawing, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.drawingAnnotation = annotation.dataRepresentation()
        }
    }

    func update(preview: UIImage, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(preview: UIImage, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(frame: CGRect, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }).flatMap { rect in
            self.access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
                guard let store = store else { return }
                store.frame = rect
            }
        }.eraseToAnyPublisher()
    }

    func update(frame: CGRect, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }).flatMap { rect in
            self.access.accessing(to: .write, id: image) { (store: ImageStore?) in
                guard let store = store else { return }
                store.frame = rect
            }
        }.eraseToAnyPublisher()
    }
}
