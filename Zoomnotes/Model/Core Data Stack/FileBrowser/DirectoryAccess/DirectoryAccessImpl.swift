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
    let access: DBAccess

    init(using moc: NSManagedObjectContext) {
        self.access = DBAccess(moc: moc)
    }

    enum DirectoryAccessError: Error {
        case moreThanOneEntryFound
        case cannotCreateFolder
        case cannotCreateDocument
        case reparentTargetNotAmongChildren
        case reparentSubjectNotFound
    }

    func read(id dir: DirectoryStoreId) throws -> DirectoryStoreLookupResult? {
        return try access.accessing(to: .read, id: dir.id) { (store: DirectoryStore?) in
            guard let store = store else { return nil }
            return DirectoryStoreLookupResult(id: DirectoryStoreId(id: store.id!),
                                             created: store.created!,
                                             name: store.name!)
        }
    }

    func updateName(of id: DirectoryStoreId, to name: String) throws {
        return try access.accessing(to: .write, id: id.id) { (store: DirectoryStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func updateName(of id: DocumentStoreId, to name: String) throws {
        return try access.accessing(to: .write, id: id.id) { (store: NoteStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func root(from description: DirectoryStoreDescription) throws {
        let store = try access.build { (store: DirectoryStore) -> DirectoryStore in
            store.id = description.id.id
            store.created = description.created
            store.name = description.name
            store.directoryChildren = NSSet()
            store.documentChildren = NSSet()

            return store
        }

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
        try access.accessing(to: .write, id: of.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.directoryChildren as? Set<DirectoryStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id == child.id }) else { return }
            store.removeFromDirectoryChildren(childToBeDeleted)
            access.delete(childToBeDeleted)

        }
    }

    func delete(child: DocumentStoreId, of: DirectoryStoreId) throws {
        try access.accessing(to: .write, id: of.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id == child.id }) else { return }

            store.removeFromDocumentChildren(childToBeDeleted)
            access.delete(childToBeDeleted)
        }
    }

    func reparent(from id: DirectoryStoreId, node: DirectoryStoreId, to dest: DirectoryStoreId) throws {
        try access.accessing(to: .write, id: id.id) { (store: DirectoryStore?) in
            assert(node.id != dest.id, "Cannot move a folder to itself")

            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else {
                return
            }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id == dest.id }) else {
                throw DirectoryAccessError.reparentTargetNotAmongChildren
            }

            guard let child: DirectoryStore = directoryChildren.first(where: { $0.id == node.id }) else {
                throw DirectoryAccessError.reparentSubjectNotFound
            }

            store.removeFromDirectoryChildren(child)
            destinationFolder.addToDirectoryChildren(child)

        }
    }

    func reparent(from id: DirectoryStoreId, node: DocumentStoreId, to dest: DirectoryStoreId) throws {
        try access.accessing(to: .write, id: id.id) { (store: DirectoryStore?) in
            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else {
                return
            }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id == dest.id }) else {
                throw DirectoryAccessError.reparentTargetNotAmongChildren
            }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let child: NoteStore = children.first(where: { $0.id == node.id }) else {
                throw DirectoryAccessError.reparentSubjectNotFound
            }

            store.removeFromDocumentChildren(child)
            destinationFolder.addToDocumentChildren(child)
        }
    }

    func children(of parent: DirectoryStoreId) throws -> [FolderBrowserViewModel.Node] {
        try access.accessing(to: .read, id: parent.id) { (store: DirectoryStore?) in
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
        try access.accessing(to: .write, id: parent.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let rootRect = try access.build(prepare: { (store: RectStore) -> RectStore in
                store.x = Float(description.root.frame.minX)
                store.y = Float(description.root.frame.minY)
                store.width = Float(description.root.frame.width)
                store.height = Float(description.root.frame.height)

                return store
            }) else { throw DirectoryAccessError.cannotCreateDocument }

            guard let rootLevel = try access.build(prepare: { (level: NoteLevelStore) -> NoteLevelStore in
                level.id = description.root.id
                level.drawing = description.root.drawing.dataRepresentation()
                level.preview = description.root.preview.pngData()!
                level.frame = rootRect
                level.sublevels = NSSet()

                return level

            }) else { throw DirectoryAccessError.cannotCreateDocument }

            guard let document = try access.build(prepare: { (document: NoteStore) -> NoteStore in
                document.id = description.id.id
                document.thumbnail = description.thumbnail.pngData()!
                document.lastModified = description.lastModified
                document.name = description.name

                document.root = rootLevel

                return document
            }) else { throw DirectoryAccessError.cannotCreateDocument }

            store.addToDocumentChildren(document)
        }
    }

    func append(directory description: DirectoryStoreDescription, to parent: DirectoryStoreId) throws {
        try access.accessing(to: .write, id: parent.id) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let subFolder = try? access.build(prepare: { (subFolder: DirectoryStore) -> DirectoryStore in
                subFolder.id = description.id.id
                subFolder.created = description.created
                subFolder.name = description.name
                subFolder.directoryChildren = NSSet()
                subFolder.documentChildren = NSSet()

                return subFolder
            }) else { throw DirectoryAccessError.cannotCreateFolder }

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
        try access.accessing(to: .read, id: id.id) { (store: NoteStore?) in
            guard let store = store else { return nil }
            guard let root = store.root else { return nil }
            guard let sublevels = root.sublevels as? Set<NoteLevelStore> else { return nil }
            guard let images = root.images as? Set<ImageStore> else { return nil }

            let frame = CGRect(x: CGFloat(root.frame!.x),
                               y: CGFloat(root.frame!.y),
                               width: CGFloat(root.frame!.width),
                               height: CGFloat(root.frame!.height))

            let subLevelDescs = sublevels.compactMap {
                try? NoteLevelDescription.from(store: $0)
            }

            let imageDescs = images.map { NoteImageDescription.from($0) }

            return NoteLevelDescription(preview: UIImage(data: root.preview!)!,
                                        frame: frame,
                                        id: root.id!,
                                        drawing: try PKDrawing(data: root.drawing!),
                                        sublevels: subLevelDescs,
                                        images: imageDescs)
        }
    }

    func updateLastModified(of file: DocumentStoreId, with date: Date) throws {
        try access.accessing(to: .write, id: file.id) { (store: NoteStore?) in
            store?.lastModified = date
        }
    }

    func updatePreviewImage(of file: DocumentStoreId, with image: UIImage) throws {
        try access.accessing(to: .write, id: file.id) { (store: NoteStore?) in
            store?.thumbnail = image.pngData()!
        }
    }
}
