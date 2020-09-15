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

    enum AccessError : Error {
        case moreThanOneUniqueEntry
    }

    private func accessing<T>(to mode: AccessMode, id: UUID, action: (NoteStore?) -> T) throws -> T {
        let request: NSFetchRequest<NoteStore> = NoteStore.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        let results = try self.moc.fetch(request)

        guard results.count < 2 else { throw AccessError.moreThanOneUniqueEntry }

        let result = action(results.first)

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

    func updateLastModified(of file: FileVM, with date: Date) throws {
        try accessing(to: .write, id: file.id) { store in
            guard let store = store else { return }
            store.lastModified = date
        }
    }

    func updateData(of file: FileVM, with data: String) throws {
        try accessing(to: .write, id: file.id) { store in
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

    func updateName(of file: FileVM, to name: String) throws {
        try accessing(to: .write, id: file.id) { store in
            guard let store = store else { return }
            store.name = name
        }
    }

    func reparent(from src: UUID, file: FileVM, to dest: UUID) throws {
        try accessing(to: .write, id: file.id) { store in
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

    func delete(_ file: FileVM) throws {
        try accessing(to: .write, id: file.id) { store in
            guard let store = store else { return }
            self.moc.delete(store)
        }
    }

    func create(from data: FileVM, with parent: UUID) throws {
        let descprition = NSEntityDescription.entity(forEntityName: String(describing: NoteStore.self),
                                                                 in: self.moc)!
        let entity = NSManagedObject(entity: descprition, insertInto: self.moc)

        entity.setValue(data.id, forKey: "id")
        entity.setValue(parent, forKey: "parent")
        entity.setValue(data.preview.image.pngData()!, forKey: "thumbnail")
        entity.setValue(data.lastModified, forKey: "lastModified")
        entity.setValue(data.name, forKey: "name")
        entity.setValue("dummy", forKey: "data")

        try self.moc.save()
    }
}

extension DocumentAccess {
    func stub(with defaults: [FileVM]) -> DocumentAccess {
        let parentId = UUID()
        for stub in defaults {
            // swiftlint:disable:next force_try
            _ = try! self.create(from: stub, with: parentId)
        }
        return self
    }
}
