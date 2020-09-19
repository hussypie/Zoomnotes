//
//  DocumentAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 14..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class DocumentAccess {
    let moc: NSManagedObjectContext

    init(using moc: NSManagedObjectContext) {
        self.moc = moc
    }

    enum AccessMode {
        case read
        case write
    }

    enum AccessError: Error {
        case moreThanOneUniqueEntry
    }

    private func accessing<T>(to mode: AccessMode, id: UUID, action: (NoteStore?) throws -> T) throws -> T {
        let request: NSFetchRequest<NoteStore> = NoteStore.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        let results = try self.moc.fetch(request)

        guard results.count < 2 else { throw AccessError.moreThanOneUniqueEntry }

        let result = try action(results.first)

        if mode == .write {
            try self.moc.save()
        }

        return result
    }

    func read(id: UUID) throws -> FileVM? {
        return try accessing(to: .read, id: id) { store in
            guard let store = store else { return nil }
            return FileVM(id: store.id!,
                          preview: UIImage(data: store.thumbnail!)!,
                          name: store.name!,
                          lastModified: store.lastModified!)
        }
    }

    func noteModel(of id: UUID) throws -> NoteModel? {
        return try accessing(to: .read, id: id) { store in
            guard let store = store else { return nil }
            assert(store.data != nil)
            return try NoteModel.from(json: store.data!)
        }
    }

    func updateLastModified(of file: UUID, with date: Date) throws {
        try accessing(to: .write, id: file) { store in
            guard let store = store else { return }
            store.lastModified = date
        }
    }

    func updateData(of file: UUID, with data: String) throws {
        try accessing(to: .write, id: file) { store in
            guard let store = store else { return }
            store.data = data
        }
    }

    func updatePreviewImage(of file: FileVM, with image: UIImage) throws {
        try accessing(to: .write, id: file.id) { store in
            guard let store = store else { return }
            store.thumbnail = image.pngData()!
        }
    }

    func updateName(of file: UUID, to name: String) throws {
        try accessing(to: .write, id: file) { store in
            guard let store = store else { return }
            store.name = name
        }
    }

    func reparent(from src: UUID, file: UUID, to dest: UUID) throws {
        try accessing(to: .write, id: file) { store in
            guard let store = store else { return }
            store.parent = dest
        }
    }

    func children(of id: UUID) throws -> [FileVM] {
        let request: NSFetchRequest<NoteStore> = NoteStore.fetchRequest()
        request.predicate = NSPredicate(format: "parent = %@", id as CVarArg)

        let results = try self.moc.fetch(request)

        return results.map { FileVM(id: $0.id!,
                                    preview: UIImage(data: $0.thumbnail!)!,
                                    name: $0.name!,
                                    lastModified: $0.lastModified!) }
    }

    func delete(_ file: UUID) throws {
        try accessing(to: .write, id: file) { store in
            guard let store = store else { return }
            self.moc.delete(store)
        }
    }

    func create(from description: StoreDescription) throws {
        let descprition = NSEntityDescription.entity(forEntityName: String(describing: NoteStore.self),
                                                                 in: self.moc)!
        let entity = NSManagedObject(entity: descprition, insertInto: self.moc)

        entity.setValue(description.id, forKey: "id")
        entity.setValue(description.parent, forKey: "parent")
        entity.setValue(description.thumbnail.pngData()!, forKey: "thumbnail")
        entity.setValue(description.lastModified, forKey: "lastModified")
        entity.setValue(description.name, forKey: "name")
        entity.setValue(description.data, forKey: "data")

        try self.moc.save()
    }
}

extension DocumentAccess {
    struct StoreDescription {
        let data: String
        let id: UUID
        let lastModified: Date
        let name: String
        let parent: UUID
        let thumbnail: UIImage
    }

    func stub(with defaults: [StoreDescription]) -> DocumentAccess {
        for stub in defaults {
            // swiftlint:disable:next force_try
            _ = try! self.create(from: stub)
        }
        return self
    }
}
