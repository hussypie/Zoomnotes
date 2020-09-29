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
import PencilKit

struct DirectoryAccessImpl: DirectoryAccess {
    let moc: NSManagedObjectContext

    init(using moc: NSManagedObjectContext) {
        self.moc = moc
    }

    enum AccessMode {
        case read
        case write
    }

    enum DirectoryAccessError: Error {
        case moreThanOneEntryFound
        case cannotCreateFolder
        case cannotCreateDocument
    }

    private func accessing<Store: NSManagedObject, T>(to mode: AccessMode,
                                                      id: UUID,
                                                      doing action: (Store?) throws -> T
    ) throws -> T {
        let request: NSFetchRequest<NSFetchRequestResult> =
            NSFetchRequest(entityName: String(describing: Store.self))
        request.predicate = NSPredicate(format: "id = %@", id as CVarArg)

        guard let entries = try moc.fetch(request) as? [Store] else {
            fatalError("Cannot cast to result type")
        }

        guard entries.count < 2 else { throw DirectoryAccessError.moreThanOneEntryFound }

        let result = try action(entries.first)

        if mode == .write {
            try self.moc.save()
        }

        return result
    }

    func read(id dir: DirectoryStoreId) throws -> DirectoryStoreLookupResult? {
        return try accessing(to: .read, id: dir.id) { (store: DirectoryStore?) in
            guard let store = store else { return nil }
            return DirectoryStoreLookupResult(id: store.id!,
                                             created: store.created!,
                                             name: store.name!)
        }
    }

    func read(id: DocumentStoreId) throws -> DocumentStoreDescription? {
        return try accessing(to: .read, id: id.id) { (store: NoteStore?) in
            guard let store = store else { return nil }
            guard let root = store.root else { return nil }

            let noteLevelAccess = NoteLevelAccessImpl(using: self.moc)

            guard let rootDesc = try noteLevelAccess.read(level: root.id!) else { return nil }

            return DocumentStoreDescription(id: store.id!,
                                            lastModified: store.lastModified!,
                                            name: store.name!,
                                            thumbnail: UIImage(data: store.thumbnail!)!,
                                            root: rootDesc)
        }
    }

    func updateName(of id: DirectoryStoreId, to name: String) throws {
        return try accessing(to: .write, id: id.id) { (store: DirectoryStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func updateName(of id: DocumentStoreId, to name: String) throws {
        return try accessing(to: .write, id: id.id) { (store: NoteStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func root(from description: DirectoryStoreDescription) throws {
        let store = try StoreBuilder<DirectoryStore>(prepare: { store in
            store.id = description.id.id
            store.created = description.created
            store.name = description.name
            store.directoryChildren = NSSet()
            store.documentChildren = NSSet()

            return store
        }).build(using: self.moc)

        if store == nil {
            throw DirectoryAccessError.cannotCreateFolder
        }

        for document in description.documentChildren {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directoryChildren {
            try self.append(directory: directory, to: description.id)
        }
    }

    func delete(child: DirectoryStoreId, of: DirectoryStoreId) throws {
        try accessing(to: .write, id: of.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.directoryChildren as? Set<DirectoryStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id == child.id }) else { return }
            store.removeFromDirectoryChildren(childToBeDeleted)
            self.moc.delete(childToBeDeleted)

        }
    }

    func delete(child: DocumentStoreId, of: DirectoryStoreId) throws {
        try accessing(to: .write, id: of.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id == child.id }) else { return }

            store.removeFromDocumentChildren(childToBeDeleted)
            self.moc.delete(childToBeDeleted)
        }
    }

    func reparent(from id: DirectoryStoreId, node: DirectoryStoreId, to dest: DirectoryStoreId) throws {
        try accessing(to: .write, id: id.id) { (store: DirectoryStore?) in
            assert(node.id != dest.id, "Cannot move a folder to itself")

            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else { return }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id == dest.id }) else {
                return
            }

            guard let child: DirectoryStore = directoryChildren.first(where: { $0.id == node.id }) else {
                return
            }

            store.removeFromDirectoryChildren(child)
            destinationFolder.addToDirectoryChildren(child)

        }
    }

    func reparent(from id: DirectoryStoreId, node: DocumentStoreId, to dest: DirectoryStoreId) throws {
        try accessing(to: .write, id: id.id) { (store: DirectoryStore?) in
            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else { return }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id == dest.id }) else {
                return
            }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let child: NoteStore = children.first(where: { $0.id == node.id }) else {
                return
            }

            store.removeFromDocumentChildren(child)
            destinationFolder.addToDocumentChildren(child)
        }
    }

    func children(of parent: DirectoryStoreId) throws -> [FolderBrowserViewModel.Node] {
        try accessing(to: .read, id: parent.id) { (store: DirectoryStore?) in
            guard let store = store else { return [] }

            guard let directories = store.directoryChildren as? Set<DirectoryStore> else { return [] }
            guard let documents = store.documentChildren as? Set<NoteStore> else { return [] }

            let directoryChildren = directories.map { (child: DirectoryStore) -> DirectoryVM in
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

    func append(document description: DocumentStoreDescription, to parent: DirectoryStoreId) throws {
        try accessing(to: .write, id: parent.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let rootRect = try StoreBuilder<RectStore>(prepare: { store in
                store.x = Float(description.root.frame.minX)
                store.y = Float(description.root.frame.minY)
                store.width = Float(description.root.frame.width)
                store.height = Float(description.root.frame.height)

                return store
            }).build(using: self.moc) else { throw DirectoryAccessError.cannotCreateDocument }

            guard let rootLevel = try StoreBuilder<NoteLevelStore>(prepare: { level in
                level.id = description.root.id
                level.drawing = description.root.drawing.dataRepresentation()
                level.preview = description.root.preview.pngData()!
                level.frame = rootRect
                level.parent = description.root.parent
                level.sublevels = NSSet()

                return level

            }).build(using: self.moc) else { throw DirectoryAccessError.cannotCreateDocument }

            guard let document = try StoreBuilder<NoteStore>(prepare: { document in
                document.id = description.id.id
                document.thumbnail = description.thumbnail.pngData()!
                document.lastModified = description.lastModified
                document.name = description.name

                document.root = rootLevel

                return document
            }).build(using: self.moc) else { throw DirectoryAccessError.cannotCreateDocument }

            store.addToDocumentChildren(document)
        }
    }

    func append(directory description: DirectoryStoreDescription, to parent: DirectoryStoreId) throws {
        try accessing(to: .write, id: parent.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let subFolder = try? StoreBuilder<DirectoryStore>(prepare: { subFolder in
                subFolder.id = description.id.id
                subFolder.created = description.created
                subFolder.name = description.name
                subFolder.directoryChildren = NSSet()
                subFolder.documentChildren = NSSet()

                return subFolder
            }).build(using: self.moc) else { throw DirectoryAccessError.cannotCreateFolder }

            store.addToDirectoryChildren(subFolder)
        }

        for document in description.documentChildren {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directoryChildren {
            try self.append(directory: directory, to: description.id)
        }
    }

    func noteModel(of id: DocumentStoreId) throws -> NoteLevelDescription? {
        try accessing(to: .read, id: id.id) { (store: NoteStore?) in
            guard let store = store else { return nil }
            guard let root = store.root else { return nil }
            guard let sublevels = root.sublevels as? Set<NoteLevelStore> else { return nil }

            let frame = CGRect(x: CGFloat(root.frame!.x),
                               y: CGFloat(root.frame!.y),
                               width: CGFloat(root.frame!.width),
                               height: CGFloat(root.frame!.height))

            let noteLevelAccess = NoteLevelAccessImpl(using: self.moc)

            let subLevelDescs = try sublevels.compactMap { try noteLevelAccess.read(level: $0.id!) }

            return NoteLevelDescription(parent: nil,
                                        preview: UIImage(data: root.preview!)!,
                                        frame: frame,
                                        id: root.id!,
                                        drawing: try PKDrawing(data: root.drawing!),
                                        sublevels: subLevelDescs)
        }
    }

    func updateLastModified(of file: DocumentStoreId, with date: Date) throws {
        try accessing(to: .write, id: file.id) { (store: NoteStore?) in
            store?.lastModified = date
        }
    }

    func updatePreviewImage(of file: DocumentStoreId, with image: UIImage) throws {
        try accessing(to: .write, id: file.id) { (store: NoteStore?) in
            store?.thumbnail = image.pngData()!
        }
    }
}
