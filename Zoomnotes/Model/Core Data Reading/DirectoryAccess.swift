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
    lazy var moc: NSManagedObjectContext = {
        guard let moc = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            fatalError("Cannot get persistent store")
        }
        return moc
    }()

    lazy var rootDirectoryId: UUID = {
        return UserDefaults.standard.withDefault(.rootDirectoryId, default: UUID())
    }()

    func root() -> DirectoryVM {
        let fetchRequest = NSFetchRequest<DirectoryStore>(entityName: String(describing: DirectoryStore.self))
        fetchRequest.predicate = NSPredicate(DirectoryStore.self) {
            $0.string(#keyPath(DirectoryStore.name)).equals(rootDirectoryName)
        }

        guard let results = try? moc.fetch(fetchRequest) else {
            fatalError("blew up")
        }

        if results.isEmpty {
            // make new
            // set userdefaults id
            // return new directory
        }

        return DirectoryVM.default

    }

    func read(name: String) -> DirectoryVM {
        return DirectoryVM.default
    }

    func read(id: UUID) -> DirectoryVM {
        return DirectoryVM.default
    }
}
