//
//  ManagedContext+inMemory.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData

extension NSPersistentContainer {
    static func inMemory(name: String) -> NSPersistentContainer {
        let persistentStoreDescription = NSPersistentStoreDescription()
        persistentStoreDescription.type = NSInMemoryStoreType

        let momd = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: name, withExtension: "momd")!)!

        let container = NSPersistentContainer(name: name, managedObjectModel: momd)
        container.persistentStoreDescriptions = [ persistentStoreDescription ]

        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError(error.localizedDescription)
            }
        })

        return container
    }
}
