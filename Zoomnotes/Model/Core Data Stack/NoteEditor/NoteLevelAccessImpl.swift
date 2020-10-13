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

class NoteLevelAccessImpl: NoteLevelAccess {
    let access: DBAccess

    init(using moc: NSManagedObjectContext) {
        self.access = DBAccess(moc: moc)
    }

    enum AccessMode {
        case read
        case write
    }

    enum AccessError: Error {
        case cannotCreateRectStore
        case cannotCreateLevelStore
        case cannotCreateImageStore
    }

    func append(level description: NoteLevelDescription, to parent: NoteLevelID) throws {
        guard let rect =
            try access.build(prepare: { (store: RectStore) -> RectStore in
                store.x = Float(description.frame.minX)
                store.y = Float(description.frame.minY)
                store.width = Float(description.frame.width)
                store.height = Float(description.frame.height)

                return store
            }) else { throw AccessError.cannotCreateRectStore }

        guard let sublevel =
            try access.build(id: description.id, prepare: { (entity: NoteLevelStore) -> NoteLevelStore in
                entity.preview = description.preview.pngData()!
                entity.frame = rect
                entity.drawing = description.drawing.dataRepresentation()

                return entity
            }) else { throw AccessError.cannotCreateLevelStore }

        try access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.addToSublevels(sublevel)
        }

        for sublevel in description.sublevels {
            try self.append(level: sublevel, to: description.id)
        }
    }

    func append(image description: NoteImageDescription, to parent: NoteLevelID) throws {
        guard let rect = try access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }) else { throw AccessError.cannotCreateRectStore }

        guard let image = try access.build(id: description.id, prepare: { (store: ImageStore) -> ImageStore in
            store.frame = rect
            store.drawingAnnotation = description.drawing.dataRepresentation()
            store.image = description.image.pngData()!
            store.preview = description.image.pngData()!

            return store
        }) else { throw AccessError.cannotCreateImageStore }

        try access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.addToImages(image)
        }
    }

    func remove(level id: NoteLevelID, from parent: NoteLevelID) throws {
        try access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            guard let sublevels = store.sublevels as? Set<NoteLevelStore> else { return }
            guard let child = sublevels.first(where: { $0.id! == id }) else { return }

            store.removeFromSublevels(child)
            access.delete(child)
        }
    }

    func remove(image id: NoteImageID, from parent: NoteLevelID) throws {
        try access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            guard let images = store.images as? Set<ImageStore> else { return }
            guard let subject = images.first(where: { $0.id! == id }) else { return }

            store.removeFromImages(subject)
            access.delete(subject)
        }
    }

    func read(level id: NoteLevelID) throws -> NoteLevelDescription? {
        return try access.accessing(to: .read, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return nil }

            return try NoteLevelDescription.from(store: store)
        }
    }

    func read(image id: NoteImageID) throws -> NoteImageDescription? {
        return try access.accessing(to: .read, id: id) { (store: ImageStore?) in
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

    func update(drawing: PKDrawing, for id: NoteLevelID) throws {
        try access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.drawing = drawing.dataRepresentation()
        }
    }

    func update(annotation: PKDrawing, image: NoteImageID) throws {
        try access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.drawingAnnotation = annotation.dataRepresentation()
        }
    }

    func update(preview: UIImage, for id: NoteLevelID) throws {
        try access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(preview: UIImage, image: NoteImageID) throws {
        try access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(frame: CGRect, for id: NoteLevelID) throws {
        guard let rect = try access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }) else { throw AccessError.cannotCreateRectStore }

        try access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.frame = rect
        }
    }

    func update(frame: CGRect, image: NoteImageID) throws {
        guard let rect = try access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }) else { throw AccessError.cannotCreateRectStore }

        try access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.frame = rect
        }
    }
}
