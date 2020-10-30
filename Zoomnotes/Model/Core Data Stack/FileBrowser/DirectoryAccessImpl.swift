//
//  DirectoryReader.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 09..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData
import Combine
import PrediKit
import PencilKit

struct DirectoryAccessImpl: DirectoryAccess {
    let access: DBAccess
    let logger: LoggerProtocol

    enum DirectoryAccessError: Error {
        case moreThanOneEntryFound
        case cannotCreateFolder
        case cannotCreateDocument
        case reparentTargetNotAmongChildren
        case reparentSubjectNotFound
        case directoryNotFound
        case documentNotFound
        case cannotGetDirectoryChildren
        case cannotGetDocumentChildren
        case tryingToMoveFolderToItself
    }

    func read(id dir: DirectoryID) -> AnyPublisher<DirectoryStoreLookupResult?, Error> {
        self.access.accessing(to: .read, id: dir) { (store: DirectoryStore?) in
            guard let store = store else { return nil }
            self.logger.info("Read directory (id: \(dir)) from DB")
            return DirectoryStoreLookupResult(id: ID(store.id!),
                                             created: store.created!,
                                             name: store.name!)
        }
    }

    func updateName(of id: DirectoryID, to name: String) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: DirectoryStore?) -> Void in
            guard let store = store else {
                self.logger.warning(LogEvent.cannotFindDirectory(id: id).message)
                throw DirectoryAccessError.directoryNotFound
            }
            store.name = name
            self.logger.info("Updated name of directory (id: \(id)) to \(name)")
        }
    }

    func updateName(of id: DocumentID, to name: String) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: NoteStore?) -> Void in
            guard let store = store else {
                self.logger.warning(LogEvent.cannotFindDocument(id: id).message)
                throw DirectoryAccessError.documentNotFound
            }
            store.name = name
            self.logger.info("Updated name of document (id: \(id)) to \(name)")
        }
    }

    func root(from description: DirectoryStoreDescription) -> AnyPublisher<Void, Error> {
        self.access.build(id: description.id) { (store: DirectoryStore) -> DirectoryStore in
            store.created = description.created
            store.name = description.name
            store.directoryChildren = NSSet()
            store.documentChildren = NSSet()

            self.logger.info("Created root directory store (id: \(description.id))")

            return store
        }.flatMap { _ -> AnyPublisher<Void, Error> in
            let a = Publishers.Sequence(sequence: description.documents)
                .flatMap { document in self.append(document: document, to: description.id) }
                .collect()

            let b = Publishers.Sequence(sequence: description.directories)
                .flatMap { directory in self.append(directory: directory, to: description.id) }
                .collect()

            return Publishers.Zip(a, b).map { _ in }.eraseToAnyPublisher()
        }
        .map { _ in
            self.logger.info("Created children of directory store (id: \(description.id))")
        }
        .eraseToAnyPublisher()
    }

    func delete(child: DirectoryID, of: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: of) { (store: DirectoryStore?) in
            guard let store = store else {
                self.logger.warning(LogEvent.cannotFindDirectory(id: of).message)
                throw DirectoryAccessError.directoryNotFound
            }

            guard let children = store.directoryChildren as? Set<DirectoryStore> else {
                throw DirectoryAccessError.cannotGetDirectoryChildren
            }
            guard let childToBeDeleted = children.first(where: { $0.id! == child }) else {
                throw DirectoryAccessError.documentNotFound
            }

            store.removeFromDirectoryChildren(childToBeDeleted)
            self.access.delete(childToBeDeleted)

            self.logger.info("Deleted directory (id: \(child))")
        }
    }

    func delete(child: DocumentID, of: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: of) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id! == child }) else { return }

            store.removeFromDocumentChildren(childToBeDeleted)
            self.access.delete(childToBeDeleted)

            self.logger.info("Deleted document (id: \(child))")
        }
    }

    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: DirectoryStore?) in
            guard id != dest else {
                throw DirectoryAccessError.tryingToMoveFolderToItself
            }

            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else {
                throw DirectoryAccessError.cannotGetDirectoryChildren
            }

            guard let destinationFolder: DirectoryStore = directoryChildren.first(where: { $0.id! == dest }) else {
                throw DirectoryAccessError.reparentTargetNotAmongChildren
            }

            guard let child: DirectoryStore = directoryChildren.first(where: { $0.id! == node }) else {
                throw DirectoryAccessError.reparentSubjectNotFound
            }

            store.removeFromDirectoryChildren(child)
            destinationFolder.addToDirectoryChildren(child)

            self.logger.info("Reparented directory (id: \(node)) to new parent (id: \(dest))")
        }
    }

    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: DirectoryStore?) in
            guard let store = store else { return }
            guard let directoryChildren = store.directoryChildren as? Set<DirectoryStore> else {
                throw DirectoryAccessError.cannotGetDirectoryChildren
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

            self.logger.info("Reparented document (id: \(node)) to new parent (id: \(dest))")
        }
    }

    func children(of parent: DirectoryID) -> AnyPublisher<[FolderBrowserNode], Error> {
        self.access.accessing(to: .read, id: parent) { (store: DirectoryStore?) in
            guard let store = store else { return [] }

            guard let directories = store.directoryChildren as? Set<DirectoryStore> else {
                throw DirectoryAccessError.cannotGetDirectoryChildren
            }
            guard let documents = store.documentChildren as? Set<NoteStore> else {
                throw DirectoryAccessError.cannotGetDocumentChildren
            }

            let directoryChildren = directories.map { (child: DirectoryStore) -> FolderBrowserNode in
                return FolderBrowserNode(id: UUID(),
                                         store: .directory(ID(child.id!)),
                                         preview: CodableImage(wrapping: UIImage.folder()),
                                         name: child.name!,
                                         lastModified: child.created!)
            }

            let documentChildren = documents.map {
                return FolderBrowserNode(id: UUID(),
                                         store: .document(ID($0.id!)),
                                         preview: CodableImage(wrapping: UIImage(data: $0.thumbnail!)!),
                                         name: $0.name!,
                                         lastModified: $0.lastModified!)
            }

            self.logger.info("Read children of directory (id: \(parent))")
            return directoryChildren + documentChildren
        }
    }

    func append(document description: DocumentStoreDescription, to parent: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.root.frame.minX)
            store.y = Float(description.root.frame.minY)
            store.width = Float(description.root.frame.width)
            store.height = Float(description.root.frame.height)

            return store
        }).flatMap { rootRect in
            return self.access.build(id: description.root.id, prepare: { (level: NoteLevelStore) -> NoteLevelStore in
                level.drawing = description.root.drawing.dataRepresentation()
                level.preview = description.root.preview.pngData()!
                level.frame = rootRect
                level.sublevels = NSSet()

                return level
            })
        }.flatMap { rootLevel in
            self.access.build(id: description.id, prepare: { (document: NoteStore) -> NoteStore in
                document.thumbnail = description.thumbnail.pngData()!
                document.lastModified = description.lastModified
                document.name = description.name

                document.root = rootLevel

                return document
            })
        }.flatMap { document in
            self.access.accessing(to: .write, id: parent) { (store: DirectoryStore?) throws -> Void in
                guard let store = store else { throw DirectoryAccessError.cannotCreateDocument }
                guard let document = document else { throw DirectoryAccessError.cannotCreateDocument }
                store.addToDocumentChildren(document)
            }
        }
        .map { _ in
            self.logger.info("Appended document (id: \(description.id)) to parent (id: \(parent)")

        }
        .eraseToAnyPublisher()
    }

    func append(directory description: DirectoryStoreDescription, to parent: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.build(id: description.id, prepare: { (subFolder: DirectoryStore) -> DirectoryStore in
            subFolder.created = description.created
            subFolder.name = description.name
            subFolder.directoryChildren = NSSet()
            subFolder.documentChildren = NSSet()

            return subFolder
        }).flatMap { subFolder in
            self.access.accessing(to: .write, id: parent) { (store: DirectoryStore?) throws -> Void in
                guard let store = store else { throw DirectoryAccessError.cannotCreateFolder }
                guard let subFolder = subFolder else { throw DirectoryAccessError.cannotCreateFolder }
                store.addToDirectoryChildren(subFolder)
            }
        }.flatMap { _ -> AnyPublisher<Void, Error> in
            let a = Publishers.Sequence(sequence: description.documents)
                .flatMap { document in self.append(document: document, to: description.id) }
                .collect()

            let b = Publishers.Sequence(sequence: description.directories)
                .flatMap { directory in self.append(directory: directory, to: description.id) }
                .collect()

            return Publishers.Zip(a, b).map { _ in }.eraseToAnyPublisher()
        }
        .map { _ in
            self.logger.info("Appended directory (id: \(description.id)) and all children to parent (id: \(parent)")

        }
        .eraseToAnyPublisher()
    }

    func noteModel(of id: DocumentID) -> AnyPublisher<DocumentLookupResult?, Error> {
        self.access.accessing(to: .read, id: id) { (store: NoteStore?) in
            guard let store = store else { return nil }
            guard let root = store.root else { return nil }
            guard let sublevels = root.sublevels as? Set<NoteLevelStore> else { return nil }
            guard let images = root.images as? Set<ImageStore> else { return nil }

            let subLevelDescs = sublevels.map(SublevelDescription.from)
            let imageDescs = images.map(SubImageDescription.from)

            let rootDesc = NoteLevelLookupResult(id: ID(root.id!),
                                                 drawing: try PKDrawing(data: root.drawing!),
                                                 sublevels: subLevelDescs,
                                                 images: imageDescs)

            let imageDrawer = (store.imageDrawer as? Set<ImageStore>)?.map(SubImageDescription.from) ?? []
            let levelDrawer = (store.drawer as? Set<NoteLevelStore>)?.map(SublevelDescription.from) ?? []

            let imageTrash = (store.imageTrash as? Set<ImageStore>)?.map(SubImageDescription.from) ?? []
            let levelTrash = (store.trash as? Set<NoteLevelStore>)?.map(SublevelDescription.from) ?? []

            self.logger.info("Create note model of document (id: \(id))")

            return DocumentLookupResult(id: ID(store.id!),
                                        lastModified: store.lastModified!,
                                        name: store.name!,
                                        imageDrawer: imageDrawer,
                                        levelDrawer: levelDrawer,
                                        imageTrash: imageTrash,
                                        levelTrash: levelTrash,
                                        root: rootDesc)
        }
    }

    func updateLastModified(of file: DocumentID, with date: Date) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: file) { (store: NoteStore?) in
            guard let store = store else {
                self.logger.warning(LogEvent.cannotFindDocument(id: file).message)
                throw DirectoryAccessError.documentNotFound
            }
            store.lastModified = date

            self.logger.info("Updated last modified of file (id: \(file)) to \(date)")
        }
    }

    func updatePreviewImage(of file: DocumentID, with image: UIImage) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: file) { (store: NoteStore?) in
            guard let store = store else {
                self.logger.warning(LogEvent.cannotFindDocument(id: file).message)
                throw DirectoryAccessError.documentNotFound
            }
            store.thumbnail = image.pngData()!

            self.logger.info("Updated preview image of file (id: \(file))")
        }
    }
}
