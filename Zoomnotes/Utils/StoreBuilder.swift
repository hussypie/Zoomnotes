//
//  StoreBuilder.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData

struct StoreBuilder<T: NSManagedObject> {
    let prepare: (T) -> T

    func build(using moc: NSManagedObjectContext) throws -> T? {
        guard let description =
            NSEntityDescription.entity(forEntityName: String(describing: T.self),
                                        in: moc) else { return nil }
        guard let entity =
            NSManagedObject(entity: description, insertInto: moc) as? T else { return nil}

        let result = prepare(entity)

        try moc.save()

        return result
    }
}
