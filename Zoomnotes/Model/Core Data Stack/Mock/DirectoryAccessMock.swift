//
//  DirectoryAccessMock.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
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

    func read(id: DirectoryID) throws -> DirectoryStoreLookupResult? {
        guard let desc = directories[id] else { return nil }
        return DirectoryStoreLookupResult(id: desc.id,
                                          created: desc.created,
                                          name: desc.name)
    }

    func noteModel(of id: DocumentID) throws -> NoteLevelDescription? {
        return documents[id]?.root
    }

    func updateName(of id: DocumentID, to name: String) throws {
        guard let desc = documents[id] else { return }
        documents[id] = DocumentStoreDescription(id: desc.id,
                                                    lastModified: desc.lastModified,
                                                    name: name,
                                                    thumbnail: desc.thumbnail,
                                                    root: desc.root)
    }

    func updateName(of id: DirectoryID, to name: String) throws {
        guard let desc = directories[id] else { return }
        directories[id] = DirectoryStoreDescription(
            id: desc.id,
            created: desc.created,
            name: name,
            documents: desc.documents,
            directories: desc.directories
        )
    }

    func updateLastModified(of file: DocumentID, with date: Date) throws {
        guard let desc = documents[file] else { return }
        documents[file] = DocumentStoreDescription(id: desc.id,
                                                    lastModified: date,
                                                    name: desc.name,
                                                    thumbnail: desc.thumbnail,
                                                    root: desc.root)
    }

    func updatePreviewImage(of file: DocumentID, with image: UIImage) throws {
        guard let desc = documents[file] else { return }
        documents[file] = DocumentStoreDescription(id: desc.id,
                                                    lastModified: desc.lastModified,
                                                    name: desc.name,
                                                    thumbnail: image,
                                                    root: desc.root)
    }

    func root(from description: DirectoryStoreDescription) throws {
        directories[description.id] = description

        for document in description.documents {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directories {
            try self.append(directory: directory, to: description.id)
        }
    }

    func delete(child: DocumentID, of: DirectoryID) throws {
        documents.removeValue(forKey: child)
    }

    func delete(child: DirectoryID, of: DirectoryID) throws {
        guard let desc = directories[child] else { return }

        for document in desc.documents {
            try self.delete(child: document.id, of: child)
        }

        for directory in desc.directories {
            try self.delete(child: directory.id, of: child)
        }

        directories.removeValue(forKey: child)
    }

    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) throws {
        guard let doc = documents[node] else { return }
        guard let from = directories[id] else { return }
        guard let to = directories[dest] else { return }

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
    }

    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) throws {
        guard let dir = directories[node] else { return }
        guard let from = directories[id] else { return }
        guard let to = directories[dest] else { return }

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
    }

    func children(of parent: DirectoryID) throws -> [FolderBrowserViewModel.Node] {
        guard let dir = directories[parent] else { return [] }
        let dirs = dir.directories.map { FolderBrowserViewModel.Node.from($0) }
        let docs = dir.documents.map { FolderBrowserViewModel.Node.from($0) }
        return dirs + docs
    }

    func append(document description: DocumentStoreDescription, to id: DirectoryID) throws {
        guard let desc = directories[id] else { return }
        documents[description.id] = description
        directories[id] = DirectoryStoreDescription(
            id: desc.id,
            created: desc.created,
            name: desc.name,
            documents: desc.documents + [description],
            directories: desc.directories)

    }

    func append(directory description: DirectoryStoreDescription, to id: DirectoryID) throws {
        guard let desc = directories[id] else { return }
        directories[id] = DirectoryStoreDescription(
            id: desc.id,
            created: desc.created,
            name: desc.name,
            documents: desc.documents,
            directories: desc.directories + [description]
        )

        directories[description.id] = description

        for document in description.documents {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directories {
            try self.append(directory: directory, to: description.id)
        }
    }
}
