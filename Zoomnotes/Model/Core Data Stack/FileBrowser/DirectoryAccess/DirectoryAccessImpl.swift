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

    func read(id dir: DirectoryID) throws -> DirectoryStoreLookupResult? {
        return try access.accessing(to: .read, id: dir) { (store: DirectoryStore?) in
            guard let store = store else { return nil }
            return DirectoryStoreLookupResult(id: ID(store.id!),
                                             created: store.created!,
                                             name: store.name!)
        }
    }

    func updateName(of id: DirectoryID, to name: String) throws {
        return try access.accessing(to: .write, id: id) { (store: DirectoryStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func updateName(of id: DocumentID, to name: String) throws {
        return try access.accessing(to: .write, id: id) { (store: NoteStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func root(from description: DirectoryStoreDescription) throws {
        let store = try access.build(id: description.id) { (store: DirectoryStore) -> DirectoryStore in
            store.created = description.created
            store.name = description.name
            store.directoryChildren = NSSet()
            store.documentChildren = NSSet()

            return store
        }

        if store == nil {
            throw DirectoryAccessError.cannotCreateFolder
        }

        for document in description.documents {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directories {
            try self.append(directory: directory, to: description.id)
        }
    }

    func delete(child: DirectoryID, of: DirectoryID) throws {
        try access.accessing(to: .write, id: of) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.directoryChildren as? Set<DirectoryStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id! == child }) else { return }
            store.removeFromDirectoryChildren(childToBeDeleted)
            access.delete(childToBeDeleted)

        }
    }

    func delete(child: DocumentID, of: DirectoryID) throws {
        try access.accessing(to: .write, id: of) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id! == child }) else { return }

            store.removeFromDocumentChildren(childToBeDeleted)
            access.delete(childToBeDeleted)
        }
    }

    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) throws {
        try access.accessing(to: .write, id: id) { (store: DirectoryStore?) in
            assert(node != dest, "Cannot move a folder to itself")

            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else {
                return
            }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id! == dest }) else {
                throw DirectoryAccessError.reparentTargetNotAmongChildren
            }

            guard let child: DirectoryStore = directoryChildren.first(where: { $0.id! == node }) else {
                throw DirectoryAccessError.reparentSubjectNotFound
            }

            store.removeFromDirectoryChildren(child)
            destinationFolder.addToDirectoryChildren(child)

        }
    }

    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) throws {
        try access.accessing(to: .write, id: id) { (store: DirectoryStore?) in
            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else {
                return
            }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id! == dest }) else {
                throw DirectoryAccessError.reparentTargetNotAmongChildren
            }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let child: NoteStore = children.first(where: { $0.id! == node }) else {
                throw DirectoryAccessError.reparentSubjectNotFound
            }

            store.removeFromDocumentChildren(child)
            destinationFolder.addToDocumentChildren(child)
        }
    }

    func children(of parent: DirectoryID) throws -> [FolderBrowserViewModel.Node] {
        try access.accessing(to: .read, id: parent) { (store: DirectoryStore?) in
            guard let store = store else { return [] }

            guard let directories = store.directoryChildren as? Set<DirectoryStore> else { return [] }
            guard let documents = store.documentChildren as? Set<NoteStore> else { return [] }

            let directoryChildren = directories.map { (child: DirectoryStore) -> DirectoryVM in
                return DirectoryVM(id: UUID(),
                                   store: ID(child.id!),
                                   name: child.name!,
                                   created: child.created!)
            }.map { FolderBrowserViewModel.Node.directory($0) }

            let documentChildren = documents.map {
                return FileVM(id: UUID(),
                              store: ID($0.id!),
                              preview: UIImage(data: $0.thumbnail!)!,
                              name: $0.name!,
                              lastModified: $0.lastModified!)
            }.map { FolderBrowserViewModel.Node.file($0) }

            return directoryChildren + documentChildren
        }
    }

    func append(document description: DocumentStoreDescription, to parent: DirectoryID) throws {
        try access.accessing(to: .write, id: parent) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let rootRect = try access.build(prepare: { (store: RectStore) -> RectStore in
                store.x = Float(description.root.frame.minX)
                store.y = Float(description.root.frame.minY)
                store.width = Float(description.root.frame.width)
                store.height = Float(description.root.frame.height)

                return store
            }) else { throw DirectoryAccessError.cannotCreateDocument }

            guard let rootLevel = try access.build(id: description.root.id, prepare: { (level: NoteLevelStore) -> NoteLevelStore in
                level.drawing = description.root.drawing.dataRepresentation()
                level.preview = description.root.preview.pngData()!
                level.frame = rootRect
                level.sublevels = NSSet()

                return level

            }) else { throw DirectoryAccessError.cannotCreateDocument }

            guard let document = try access.build(id: description.id, prepare: { (document: NoteStore) -> NoteStore in
                document.thumbnail = description.thumbnail.pngData()!
                document.lastModified = description.lastModified
                document.name = description.name

                document.root = rootLevel

                return document
            }) else { throw DirectoryAccessError.cannotCreateDocument }

            store.addToDocumentChildren(document)
        }
    }

    func append(directory description: DirectoryStoreDescription, to parent: DirectoryID) throws {
        try access.accessing(to: .write, id: parent) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let subFolder = try? access.build(id: description.id, prepare: { (subFolder: DirectoryStore) -> DirectoryStore in
                subFolder.created = description.created
                subFolder.name = description.name
                subFolder.directoryChildren = NSSet()
                subFolder.documentChildren = NSSet()

                return subFolder
            }) else { throw DirectoryAccessError.cannotCreateFolder }

            store.addToDirectoryChildren(subFolder)
        }

        for document in description.documents {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directories {
            try self.append(directory: directory, to: description.id)
        }
    }

    func noteModel(of id: DocumentID) throws -> NoteLevelDescription? {
        try access.accessing(to: .read, id: id) { (store: NoteStore?) in
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
                                        id: ID(root.id!),
                                        drawing: try PKDrawing(data: root.drawing!),
                                        sublevels: subLevelDescs,
                                        images: imageDescs)
        }
    }

    func updateLastModified(of file: DocumentID, with date: Date) throws {
        try access.accessing(to: .write, id: file) { (store: NoteStore?) in
            store?.lastModified = date
        }
    }

    func updatePreviewImage(of file: DocumentID, with image: UIImage) throws {
        try access.accessing(to: .write, id: file) { (store: NoteStore?) in
            store?.thumbnail = image.pngData()!
        }
    }
}
