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
    let moc: NSManagedObjectContext

    init(using moc: NSManagedObjectContext) {
        self.moc = moc
    }

    enum AccessMode {
        case read
        case write
    }

    enum AccessError: Error {
        case moreThanOneEntryFound
        case cannotCreateRectStore
        case cannotCreateLevelStore
        case cannotCreateImageStore
    }

    private func accessing<Store: NSManagedObject, T>(to mode: AccessMode,
                                                      id: UUID,
                                                      doing action: (Store?) throws -> T
    ) throws -> T {
        let request: NSFetchRequest<NSFetchRequestResult> =
            NSFetchRequest(entityName: String(describing: Store.self))
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        guard let entries = try moc.fetch(request) as? [Store] else {
            fatalError("Cannot cast to result type")
        }

        guard entries.count < 2 else { throw AccessError.moreThanOneEntryFound }

        let result = try action(entries.first)

        if mode == .write {
            try self.moc.save()
        }

        return result
    }

    func append(level description: NoteLevelDescription, to parent: UUID) throws {
        guard let rect = try StoreBuilder<RectStore>(prepare: { store in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).build(using: self.moc) else { throw AccessError.cannotCreateRectStore }

        guard let sublevel = try StoreBuilder<NoteLevelStore>(prepare: { entity in
            entity.id = description.id
            entity.preview = description.preview.pngData()!
            entity.frame = rect
            entity.drawing = description.drawing.dataRepresentation()

            return entity
        }).build(using: self.moc) else { throw AccessError.cannotCreateLevelStore }

        try accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.addToSublevels(sublevel)
        }

        for sublevel in description.sublevels {
            try self.append(level: sublevel, to: description.id)
        }
    }

    func append(image description: NoteImageDescription, to parent: UUID) throws {
        try accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }

            guard let rect = try StoreBuilder<RectStore>(prepare: { store in
                store.x = Float(description.frame.minX)
                store.y = Float(description.frame.minY)
                store.width = Float(description.frame.width)
                store.height = Float(description.frame.height)

                return store
            }).build(using: self.moc) else { throw AccessError.cannotCreateRectStore }

            guard let image = try StoreBuilder<ImageStore>(prepare: { store in
                store.frame = rect
                store.drawingAnnotation = description.drawing.dataRepresentation()
                store.id = description.id
                store.image = description.image.pngData()!
                store.preview = description.image.pngData()!

                return store
            }).build(using: self.moc) else { throw AccessError.cannotCreateImageStore }

            store.addToImages(image)
        }
    }

    func remove(level id: UUID, from parent: UUID) throws {
        try accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            guard let sublevels = store.sublevels as? Set<NoteLevelStore> else { return }
            guard let child = sublevels.first(where: { subl in subl.id == id }) else { return }

            store.removeFromSublevels(child)
            self.moc.delete(child)
        }
    }

    func remove(image id: UUID, from parent: UUID) throws {
        try accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            guard let images = store.images as? Set<ImageStore> else { return }
            guard let subject = images.first(where: { $0.id == id }) else { return }

            store.removeFromImages(subject)
            self.moc.delete(subject)
        }
    }

    func read(level id: UUID) throws -> NoteLevelDescription? {
        return try accessing(to: .read, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return nil }

            return try NoteLevelDescription.from(store: store)
        }
    }

    func update(drawing: PKDrawing, for id: UUID) throws {
        try accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.drawing = drawing.dataRepresentation()
        }
    }

    func update(annotation: PKDrawing, image: UUID) throws {
        try accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.drawingAnnotation = annotation.dataRepresentation()
        }
    }

    func update(preview: UIImage, for id: UUID) throws {
        try accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(frame: CGRect, for id: UUID) throws {
        guard let rect = try StoreBuilder<RectStore>(prepare: { store in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }).build(using: self.moc) else { throw AccessError.cannotCreateRectStore }

        try accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.frame = rect
        }
    }

    func update(frame: CGRect, image: UUID) throws {
        guard let rect = try StoreBuilder<RectStore>(prepare: { store in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }).build(using: self.moc) else { throw AccessError.cannotCreateRectStore }

        try accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.frame = rect
        }
    }
}
