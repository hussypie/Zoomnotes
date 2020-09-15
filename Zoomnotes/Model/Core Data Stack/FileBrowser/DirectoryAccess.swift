//
//  DirectoryReader.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 09..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData
import PrediKit

// swiftlint:disable private_over_fileprivate
fileprivate let rootDirectoryName = "Documents"

class DirectoryAccess {
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

    private func accessing<T>(to mode: AccessMode, id: UUID, doing action: (DirectoryStore?) -> T) throws -> T {
        let request: NSFetchRequest<DirectoryStore> = DirectoryStore.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        let entries = try moc.fetch(request)

        guard entries.count < 2 else { throw AccessError.moreThanOneEntryFound }

        let result = action(entries.first)

        if mode == .write {
            try self.moc.save()
        }

        return result
    }

    func read(id: UUID) throws -> DirectoryVM? {
        return try accessing(to: .read, id: id) { (store: DirectoryStore?) -> DirectoryVM? in
            guard let store = store else { return nil }
            return DirectoryVM(id: store.id!, name: store.name!, created: store.created!)
        }
    }

    func updateName(for directory: DirectoryVM, to name: String) throws {
        return try accessing(to: .write, id: directory.id) { store in
            guard let store = store else { return }
            store.name = name
        }
    }

    func create(from vm: DirectoryVM, with parent: UUID) throws {
        let entity = NSEntityDescription.entity(forEntityName: String(describing: DirectoryStore.self),
                                                in: self.moc)!
        let store = NSManagedObject(entity: entity, insertInto: self.moc)

        store.setValue(vm.id, forKey: "id")
        store.setValue(vm.created, forKey: "created")
        store.setValue(vm.name, forKey: "name")
        store.setValue(parent, forKey: "parent")

        try self.moc.save()
    }

    func delete(directory: DirectoryVM) throws {
        let fetchRequest: NSFetchRequest<DirectoryStore> = DirectoryStore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id = %@", directory.id as CVarArg)
        let results = try self.moc.fetch(fetchRequest)

        results.forEach {
            self.moc.delete($0)
        }

        try self.moc.save()

    }

    func reparent(from id: UUID, node: DirectoryVM, to dest: UUID) throws {
        try accessing(to: .write, id: node.id) { store in
            guard let store = store else { return }
            store.parent = dest
        }
    }

    func children(of parent: UUID) throws -> [DirectoryVM] {
        let request: NSFetchRequest<DirectoryStore> = DirectoryStore.fetchRequest()
        request.predicate = NSPredicate(format: "parent = %@", parent as CVarArg)

        let results = try self.moc.fetch(request)

        return results
            .filter { $0.id != parent }
            .map { DirectoryVM(id: $0.id!, name: $0.name!, created: $0.created!) }
    }
}

extension DirectoryAccess {
    func stub(with defaults: [DirectoryVM], to id: UUID = UUID()) -> DirectoryAccess {
        for stub in defaults {
            // swiftlint:disable:next force_try
            _ = try! self.create(from: stub, with: id)
        }
        return self
    }
}
