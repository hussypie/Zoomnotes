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
import UIKit

struct NoteLevelDescription {
    let parent: UUID
    let id: UUID
    let preview: CodableImage
    let frame: CGRect
    let drawing: PKDrawing
}

protocol NoteLevelAccessProtocol {
    func create(from description: NoteLevelDescription) throws
    func delete(level id: UUID) throws
    func read(level id: UUID) throws -> NoteLevelDescription?
    func update(drawing: PKDrawing, for id: UUID) throws
    func update(preview: CodableImage, for id: UUID) throws
    func update(frame: CGRect, for id: UUID) throws
}

class NoteLevelAccess: NoteLevelAccessProtocol {
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

    func create(from description: NoteLevelDescription) throws {
        let entityDescription = NSEntityDescription.entity(forEntityName: String(describing: NoteLevelStore.self),
                                                           in: self.moc)!

        let entity = NoteLevelStore(entity: entityDescription, insertInto: self.moc)

        entity.parent = description.parent
        entity.id = description.id

        let previewImageData = description.preview.image.pngData()!
        entity.preview = previewImageData

        let rectDescription = NSEntityDescription.entity(forEntityName: String(describing: RectStore.self),
                                                         in: self.moc)!
        let rect = RectStore(entity: rectDescription, insertInto: self.moc)
        rect.x = Float(description.frame.minX)
        rect.y = Float(description.frame.minY)
        rect.width = Float(description.frame.width)
        rect.height = Float(description.frame.height)

        entity.frame = rect

        let drawingData = description.drawing.dataRepresentation()
        entity.drawing = drawingData

        try self.moc.save()
    }

    func delete(level id: UUID) throws {
        let fetchRequest: NSFetchRequest<NoteLevelStore> = NoteLevelStore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id = %@", id as CVarArg)
        let results = try self.moc.fetch(fetchRequest)
        if results.count > 1 {
            throw AccessError.moreThanOneEntryFound
        }

        guard let first = results.first else { return }

        self.moc.delete(first)

        try self.moc.save()
    }

    func read(level id: UUID) throws -> NoteLevelDescription? {
        return try accessing(to: .read, id: id) { store in
            guard let store = store else { return nil }
            let frame = CGRect(x: CGFloat(store.frame!.x),
                               y: CGFloat(store.frame!.y),
                               width: CGFloat(store.frame!.width),
                               height: CGFloat(store.frame!.height))

            let drawing = try PKDrawing(data: store.drawing!)

            return NoteLevelDescription(parent: store.parent!,
                                        id: store.id!,
                                        preview: CodableImage(wrapping: UIImage(data: store.preview!)!),
                                        frame: frame,
                                        drawing: drawing)
        }
    }

    func update(drawing: PKDrawing, for id: UUID) throws {

    }

    func update(preview: CodableImage, for id: UUID) throws {

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
