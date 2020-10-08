//
//  DBAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData

enum DBAccessError: Error {
    case moreThanOneEntryFound
}

enum AccessMode {
    case read
    case write
}

struct DBAccess {
    let moc: NSManagedObjectContext

    func accessing<Store: NSManagedObject, T>(to mode: AccessMode,
                                                      id: UUID,
                                                      doing action: (Store?) throws -> T
    ) throws -> T {
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

    func build<T: NSManagedObject>(
        prepare: @escaping (T) -> T
    ) throws -> T? {
        return try StoreBuilder<T>(prepare: prepare).build(using: self.moc)
    }

    func delete<T: NSManagedObject>(_ thing: T) {
        self.moc.delete(thing)
    }
}
