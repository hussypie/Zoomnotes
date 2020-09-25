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

struct DirectoryAccessImpl: DirectoryAccess {
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

    private func accessing<T>(to mode: AccessMode,
                              id: UUID,
                              doing action: (DirectoryStore?) throws -> T
    ) throws -> T {
        let request: NSFetchRequest<DirectoryStore> = DirectoryStore.fetchRequest()
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        let entries = try moc.fetch(request)

        guard entries.count < 2 else { throw AccessError.moreThanOneEntryFound }

        let result = try action(entries.first)

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

    func updateName(id: UUID, to name: String) throws {
        return try accessing(to: .write, id: id) { store in
            guard let store = store else { return }
            store.name = name
        }
    }

    func create(from description: DirectoryStoreDescription) throws {
        _ = try StoreBuilder<DirectoryStore> { store in
            store.id = description.id
            store.created = description.created
            store.name = description.name
            store.directoryChildren = NSSet()
            store.documentChildren = NSSet()

            return store
        }.build(using: self.moc)

        for document in description.documentChildren {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directoryChildren {
            try self.append(directory: directory, to: description.id)
        }
    }

    func delete(child: DirectoryAccessNode, of: UUID) throws {
        try accessing(to: .write, id: of) { store in
            guard let store = store else { return }

            switch child {
            case .directory(let id):
                guard let children = store.directoryChildren as? Set<DirectoryStore> else { return }
                guard let childToBeDeleted = children.first(where: { $0.id == id }) else { return }
                store.removeFromDirectoryChildren(childToBeDeleted)
                self.moc.delete(childToBeDeleted)

            case .document(let id):
                guard let children = store.documentChildren as? Set<NoteStore> else { return }
                guard let childToBeDeleted = children.first(where: { $0.id == id }) else { return }
                store.removeFromDocumentChildren(childToBeDeleted)
                self.moc.delete(childToBeDeleted)
            }
        }
    }

    func reparent(from parent: UUID, node: DirectoryAccessNode, to dest: UUID) throws {
        try accessing(to: .write, id: parent) { store in
            assert(node.id != dest, "Cannot move a folder to itself")

            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else { return }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id == dest }) else {
                return
            }

            switch node {
            case .directory:
                guard let child: DirectoryStore = directoryChildren.first(where: { $0.id == node.id }) else {
                    return
                }

                store.removeFromDirectoryChildren(child)
                destinationFolder.addToDirectoryChildren(child)

            case .document:
                guard let children = store.documentChildren as? Set<NoteStore> else { return }
                guard let child: NoteStore = children.first(where: { $0.id == node.id }) else {
                    return
                }

                store.removeFromDocumentChildren(child)
                destinationFolder.addToDocumentChildren(child)
            }
        }
    }

    func children(of parent: UUID) throws -> [FolderBrowserViewModel.Node] {
        try accessing(to: .read, id: parent) { store in
            guard let store = store else { return [] }

            guard let directories = store.directoryChildren as? Set<DirectoryStore> else { return [] }
            guard let documents = store.documentChildren as? Set<NoteStore> else { return [] }

            let directoryChildren = directories.compactMap { (child: DirectoryStore) -> DirectoryVM in
                return DirectoryVM(id: child.id!,
                                   name: child.name!,
                                   created: child.created!)
            }.map { FolderBrowserViewModel.Node.directory($0) }

            let documentChildren = documents.map {
                return FileVM(id: $0.id!,
                       preview: UIImage(data: $0.thumbnail!)!,
                       name: $0.name!,
                       lastModified: $0.lastModified!)
            }.map { FolderBrowserViewModel.Node.file($0) }

            return directoryChildren + documentChildren
        }
    }

    func append(document description: DocumentStoreDescription, to id: UUID) throws {
        try accessing(to: .write, id: id) { store in
            guard let store = store else { return }

            guard let document = try? StoreBuilder<NoteStore>(prepare: { document in
                document.id = description.id
                document.thumbnail = description.thumbnail.pngData()!
                document.lastModified = description.lastModified
                document.name = description.name
                document.data = description.data

                return document
            }).build(using: self.moc) else { return }

            store.addToDocumentChildren(document)
        }
    }

    func append(directory description: DirectoryStoreDescription, to id: UUID) throws {
        try accessing(to: .write, id: id) { store in
            guard let store = store else { return }

            guard let subFolder = try? StoreBuilder<DirectoryStore>(prepare: { subFolder in
                subFolder.id = description.id
                subFolder.created = description.created
                subFolder.name = description.name
                subFolder.directoryChildren = NSSet()
                subFolder.documentChildren = NSSet()

                return subFolder
            }).build(using: self.moc) else { return }

            store.addToDirectoryChildren(subFolder)
        }

        for document in description.documentChildren {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directoryChildren {
            try self.append(directory: directory, to: description.id)
        }
    }
}
