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
    }

    private func accessing<T>(to mode: AccessMode,
                              id: UUID,
                              doing action: (NoteLevelStore?) throws -> T
    ) throws -> T {
        let request: NSFetchRequest<NoteLevelStore> = NoteLevelStore.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        let entries = try moc.fetch(request)

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

        try accessing(to: .write, id: parent) { store in
            guard let store = store else { return }
            store.addToSublevels(sublevel)
        }

        for sublevel in description.sublevels {
            try self.append(level: sublevel, to: description.id)
        }
    }

    func remove(level id: UUID, from parent: UUID) throws {
        try accessing(to: .write, id: parent) { store in
            guard let store = store else { return }
            guard let sublevels = store.sublevels as? Set<NoteLevelStore> else { return }
            guard let child = sublevels.first(where: { subl in subl.id == id }) else { return }

            store.removeFromSublevels(child)
            self.moc.delete(child)
        }
    }

    func read(level id: UUID) throws -> NoteLevelDescription? {
        return try accessing(to: .read, id: id) { store in
            guard let store = store else { return nil }

            return try NoteLevelDescription.from(store: store)
        }
    }

    func update(drawing: PKDrawing, for id: UUID) throws {
        try accessing(to: .write, id: id) { store in
            guard let store = store else { return }
            store.drawing = drawing.dataRepresentation()
        }
    }

    func update(preview: UIImage, for id: UUID) throws {
        try accessing(to: .write, id: id) { store in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(frame: CGRect, for id: UUID) throws {

        let rectDescription = NSEntityDescription.entity(forEntityName: String(describing: RectStore.self),
                                                         in: self.moc)!
        let rect = RectStore(entity: rectDescription, insertInto: self.moc)
        rect.x = Float(frame.minX)
        rect.y = Float(frame.minY)
        rect.width = Float(frame.width)
        rect.height = Float(frame.height)

        try accessing(to: .write, id: id) { store in
            guard let store = store else { return }
            store.frame = rect
        }
    }
}
