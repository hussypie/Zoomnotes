//
//  DBAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData

struct ID<T>: Hashable, Codable {
    fileprivate let id: UUID
    init(_ id: UUID) {
        self.id = id
    }
}

func ==<T>(lhs: ID<T>, rhs: UUID) -> Bool {
    return lhs.id == rhs
}

func ==<T>(lhs: UUID, rhs: ID<T>) -> Bool {
    return rhs.id == lhs
}

class StoreBuilder<T: NSManagedObject> {
    private var dead: Bool = false
    let prepare: (T) -> T

    init(prepare: @escaping (T) -> T) { self.prepare = prepare }

    private func buildI(using moc: NSManagedObjectContext, customize: (T) -> Void) throws -> T? {
        guard !dead else { fatalError("Head Coffin!") }

        guard let description =
            NSEntityDescription.entity(forEntityName: String(describing: T.self),
                                       in: moc) else { return nil }
        guard let entity =
            NSManagedObject(entity: description, insertInto: moc) as? T else { return nil}

        let result = prepare(entity)

        customize(result)

        try moc.save()

        dead = true
        return result
    }

    func build<U: NoteEntity>(id: ID<U>?, using moc: NSManagedObjectContext) throws -> T? {
        try self.buildI(using: moc) { result in
            if let id = id?.id {
                result.setValue(id, forKey: "id")
            }
        }
    }

    func build(using moc: NSManagedObjectContext) throws -> T? {
        try self.buildI(using: moc) { result in }
    }
}

enum DBAccessError: Error {
    case moreThanOneEntryFound
}

enum AccessMode {
    case read
    case write
}

struct DBAccess {
    let moc: NSManagedObjectContext

    func accessing<Store: NSManagedObject, T, U>(to mode: AccessMode,
                                                 id: ID<U>,
                                                 doing action: (Store?) throws -> T
    ) throws -> T {
        let id = id.id
        let request: NSFetchRequest<NSFetchRequestResult> =
            NSFetchRequest(entityName: String(describing: Store.self))
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        guard let entries = try moc.fetch(request) as? [Store] else {
            fatalError("Cannot cast to result type")
        }
        
        guard entries.count < 2 else { throw DBAccessError.moreThanOneEntryFound }

        let result = try action(entries.first)

        if mode == .write {
            try self.moc.save()
        }

        return result
    }

    func build<T: NoteEntity, U: NSManagedObject>(
        id: ID<T>?,
        prepare: @escaping (U) -> U
    ) throws -> U? {
        return try StoreBuilder(prepare: prepare).build(id: id, using: self.moc)
    }

    func build<U: NSManagedObject>(
        prepare: @escaping (U) -> U
    ) throws -> U? {
        return try StoreBuilder(prepare: prepare).build(using: self.moc)
    }

    func delete<T: NSManagedObject>(_ thing: T) {
        self.moc.delete(thing)
    }
}
