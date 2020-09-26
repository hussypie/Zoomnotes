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
import PencilKit

struct DocumentAccessImpl: DocumentAccess {
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

    private func accessing<T>(to mode: AccessMode,
                              id: UUID,
                              action: (NoteStore?) throws -> T
    ) throws -> T {
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

    func noteModel(of id: UUID) throws -> NoteLevelDescription? {
        return try accessing(to: .read, id: id) { store in
            guard let store = store else { return nil }

            assert(store.root != nil)

            return try NoteLevelDescription.from(store: store.root!)
        }
    }

    func updateLastModified(of file: UUID, with date: Date) throws {
        try accessing(to: .write, id: file) { store in
            guard let store = store else { return }
            store.lastModified = date
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
}
