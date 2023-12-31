//
//  DirectoryAccessMock.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine
import PencilKit

class DirectoryAccessMock: DirectoryAccess {
    typealias DocumentsTable = [DocumentID: DocumentStoreDescription]
    typealias DirectoriesTable = [DirectoryID: DirectoryStoreDescription]
    var documents: DocumentsTable
    var directories: DirectoriesTable

    init(documents: DocumentsTable,
         directories: DirectoriesTable
    ) {
        self.documents = documents
        self.directories = directories
    }

    func read(id: DirectoryID) -> AnyPublisher<DirectoryStoreLookupResult?, Error> {
        guard let desc = directories[id] else { return Future { $0(.success(nil)) }.eraseToAnyPublisher() }
        let res = DirectoryStoreLookupResult(id: desc.id,
                                          created: desc.created,
                                          name: desc.name)
        return Future { $0(.success(res)) }.eraseToAnyPublisher()
    }

    func noteModel(of id: DocumentID) -> AnyPublisher<DocumentLookupResult?, Error> {
        let doc = documents[id]!

        let rootDesc = NoteLevelLookupResult(id: doc.root.id,
                                             drawing: doc.root.drawing,
                                             sublevels: doc.root.sublevels.map { SublevelDescription(id: $0.id, preview: $0.preview, frame: $0.frame) },
                                             images: doc.root.images.map { SubImageDescription(id: $0.id, preview: $0.preview, frame: $0.frame) })

        let result = DocumentLookupResult(id: doc.id,
                                          lastModified: doc.lastModified,
                                          name: doc.name,
                                          imageDrawer: doc.imageDrawer.map { SubImageDescription(id: $0.id, preview: $0.preview, frame: $0.frame) },
                                          levelDrawer: doc.levelDrawer.map { SublevelDescription(id: $0.id, preview: $0.preview, frame: $0.frame) },
                                          imageTrash: doc.imageTrash.map { SubImageDescription(id: $0.id, preview: $0.preview, frame: $0.frame) },
                                          levelTrash: doc.levelDrawer.map { SublevelDescription(id: $0.id, preview: $0.preview, frame: $0.frame) },
                                          root: rootDesc)

        return Future { $0(.success(result)) }.eraseToAnyPublisher()
    }

    func updateName(of id: DocumentID, to name: String) -> AnyPublisher<Void, Error> {
        guard let desc = documents[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        documents[id] = DocumentStoreDescription(id: desc.id,
                                                    lastModified: desc.lastModified,
                                                    name: name,
                                                    thumbnail: desc.thumbnail,
                                                    imageDrawer: [],
                                                    levelDrawer: [],
                                                    imageTrash: [],
                                                    levelTrash: [],
                                                    root: desc.root)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func updateName(of id: DirectoryID, to name: String) -> AnyPublisher<Void, Error> {
        guard let desc = directories[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        directories[id] = DirectoryStoreDescription(
            id: desc.id,
            created: desc.created,
            name: name,
            documents: desc.documents,
            directories: desc.directories
        )
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func updateLastModified(of file: DocumentID, with date: Date) -> AnyPublisher<Void, Error> {
        guard let desc = documents[file] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        documents[file] = DocumentStoreDescription(id: desc.id,
                                                    lastModified: date,
                                                    name: desc.name,
                                                    thumbnail: desc.thumbnail,
                                                    imageDrawer: desc.imageDrawer,
                                                    levelDrawer: desc.levelDrawer,
                                                    imageTrash: desc.imageTrash,
                                                    levelTrash: desc.levelTrash,
                                                    root: desc.root)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func updatePreviewImage(of file: DocumentID, with image: UIImage) -> AnyPublisher<Void, Error> {
        guard let desc = documents[file] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        documents[file] = DocumentStoreDescription(id: desc.id,
                                                    lastModified: desc.lastModified,
                                                    name: desc.name,
                                                    thumbnail: image,
                                                    imageDrawer: desc.imageDrawer,
                                                    levelDrawer: desc.levelDrawer,
                                                    imageTrash: desc.imageTrash,
                                                    levelTrash: desc.levelTrash,
                                                    root: desc.root)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func root(from description: DirectoryStoreDescription) -> AnyPublisher<Void, Error> {
        directories[description.id] = description

        for document in description.documents {
            _ = self.append(document: document, to: description.id)
        }

        for directory in description.directories {
            _ = self.append(directory: directory, to: description.id)
        }
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func delete(child: DocumentID, of: DirectoryID) -> AnyPublisher<Void, Error> {
        documents.removeValue(forKey: child)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func delete(child: DirectoryID, of: DirectoryID) -> AnyPublisher<Void, Error> {
        guard let desc = directories[child] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }

        for document in desc.documents {
            _ = self.delete(child: document.id, of: child)
        }

        for directory in desc.directories {
            _ = self.delete(child: directory.id, of: child)
        }

        directories.removeValue(forKey: child)

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        guard let doc = documents[node] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        guard let from = directories[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        guard let to = directories[dest] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }

        directories[from.id] = DirectoryStoreDescription(
            id: from.id,
            created: from.created,
            name: from.name,
            documents: from.documents.filter { $0.id != node },
            directories: from.directories
        )

        directories[to.id] = DirectoryStoreDescription(
            id: to.id,
            created: to.created,
            name: to.name,
            documents: to.documents + [doc],
            directories: from.directories
        )

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        guard let dir = directories[node] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        guard let from = directories[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        guard let to = directories[dest] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }

        directories[from.id] = DirectoryStoreDescription(
            id: from.id,
            created: from.created,
            name: from.name,
            documents: from.documents,
            directories: from.directories.filter { $0.id != node }
        )

        directories[to.id] = DirectoryStoreDescription(
            id: to.id,
            created: to.created,
            name: to.name,
            documents: to.documents,
            directories: from.directories + [dir]
        )

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func children(of parent: DirectoryID) -> AnyPublisher<[FolderBrowserNode], Error> {
        guard let dir = directories[parent] else { return Future { $0(.success([])) }.eraseToAnyPublisher() }
        let dirs = dir.directories.map { FolderBrowserNode.from($0) }
        let docs = dir.documents.map { FolderBrowserNode.from($0) }

        return Future { $0(.success(dirs + docs)) }.eraseToAnyPublisher()
    }

    func append(document description: DocumentStoreDescription, to id: DirectoryID) -> AnyPublisher<Void, Error> {
        guard let desc = directories[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        documents[description.id] = description
        directories[id] = DirectoryStoreDescription(
            id: desc.id,
            created: desc.created,
            name: desc.name,
            documents: desc.documents + [description],
            directories: desc.directories)

        return Future { $0(.success(())) }.eraseToAnyPublisher()

    }

    func append(directory description: DirectoryStoreDescription, to id: DirectoryID) -> AnyPublisher<Void, Error> {
        guard let desc = directories[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        directories[id] = DirectoryStoreDescription(
            id: desc.id,
            created: desc.created,
            name: desc.name,
            documents: desc.documents,
            directories: desc.directories + [description]
        )

        directories[description.id] = description

        for document in description.documents {
            _ = self.append(document: document, to: description.id)
        }

        for directory in description.directories {
            _ = self.append(directory: directory, to: description.id)
        }

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }
}
