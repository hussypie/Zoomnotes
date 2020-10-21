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

    enum DirectoryAccessError: Error {
        case moreThanOneEntryFound
        case cannotCreateFolder
        case cannotCreateDocument
        case reparentTargetNotAmongChildren
        case reparentSubjectNotFound
    }

    func read(id dir: DirectoryID) -> AnyPublisher<DirectoryStoreLookupResult?, Error> {
        self.access.accessing(to: .read, id: dir) { (store: DirectoryStore?) in
            guard let store = store else { return nil }
            return DirectoryStoreLookupResult(id: ID(store.id!),
                                             created: store.created!,
                                             name: store.name!)
        }
    }

    func updateName(of id: DirectoryID, to name: String) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: DirectoryStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func updateName(of id: DocumentID, to name: String) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: NoteStore?) -> Void in
            guard let store = store else { return }
            store.name = name
        }
    }

    func root(from description: DirectoryStoreDescription) -> AnyPublisher<Void, Error> {
        self.access.build(id: description.id) { (store: DirectoryStore) -> DirectoryStore in
            store.created = description.created
            store.name = description.name
            store.directoryChildren = NSSet()
            store.documentChildren = NSSet()

            return store
        }.flatMap { _ -> AnyPublisher<Void, Error> in
            let a = Publishers.Sequence(sequence: description.documents)
                .flatMap { document in self.append(document: document, to: description.id) }
                .collect()

            let b = Publishers.Sequence(sequence: description.directories)
                .flatMap { directory in self.append(directory: directory, to: description.id) }
                .collect()

            return Publishers.Zip(a, b).map { _ in }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

    func delete(child: DirectoryID, of: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: of) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.directoryChildren as? Set<DirectoryStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id! == child }) else { return }
            store.removeFromDirectoryChildren(childToBeDeleted)
            self.access.delete(childToBeDeleted)
        }
    }

    func delete(child: DocumentID, of: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: of) { (store: DirectoryStore?) in
            guard let store = store else { return }

            guard let children = store.documentChildren as? Set<NoteStore> else { return }
            guard let childToBeDeleted = children.first(where: { $0.id! == child }) else { return }

            store.removeFromDocumentChildren(childToBeDeleted)
            self.access.delete(childToBeDeleted)
        }
    }

    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: DirectoryStore?) in
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

    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: id) { (store: DirectoryStore?) in
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

    func children(of parent: DirectoryID) -> AnyPublisher<[FolderBrowserNode], Error> {
        self.access.accessing(to: .read, id: parent) { (store: DirectoryStore?) in
            guard let store = store else { return [] }

            guard let directories = store.directoryChildren as? Set<DirectoryStore> else { return [] }
            guard let documents = store.documentChildren as? Set<NoteStore> else { return [] }

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
        }.eraseToAnyPublisher()
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
        }.eraseToAnyPublisher()
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

            let imageTrash = (store.imageDrawer as? Set<ImageStore>)?.map(SubImageDescription.from) ?? []
            let levelTrash = (store.drawer as? Set<NoteLevelStore>)?.map(SublevelDescription.from) ?? []

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
            store?.lastModified = date
        }
    }

    func updatePreviewImage(of file: DocumentID, with image: UIImage) -> AnyPublisher<Void, Error> {
        self.access.accessing(to: .write, id: file) { (store: NoteStore?) in
            store?.thumbnail = image.pngData()!
        }
    }
}
