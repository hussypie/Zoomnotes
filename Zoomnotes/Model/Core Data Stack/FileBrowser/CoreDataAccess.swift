//
//  CoreDataAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData

class CoreDataAccess {
    private(set) var directory: DirectoryAccess
    private(set) var file: DocumentAccess

    init(using moc: NSManagedObjectContext) {
        self.directory = DirectoryAccess(using: moc)
        self.file = DocumentAccess(using: moc)
    }
}

extension CoreDataAccess {
    static var stub: CoreDataAccess {
        let container = NSPersistentContainer.inMemory(name: "Zoomnotes")
        return CoreDataAccess(using: container.viewContext)
    }
}
