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
    var documents: [UUID: DocumentStoreDescription]
    var directories: [UUID: DirectoryStoreDescription]

    init(documents: [UUID: DocumentStoreDescription],
         directories: [UUID: DirectoryStoreDescription]
    ) {
        self.documents = documents
        self.directories = directories
    }

    func read(id: DocumentStoreId) throws -> DocumentStoreDescription? {
        return documents[id.id]
    }

    func read(id: DirectoryStoreId) throws -> DirectoryStoreLookupResult? {
        guard let desc = directories[id.id] else { return nil }
        return DirectoryStoreLookupResult(id: desc.id.id,
                                          created: desc.created,
                                          name: desc.name)
    }

    func noteModel(of id: DocumentStoreId) throws -> NoteLevelDescription? {
        return documents[id.id]?.root
    }

    func updateName(of id: DocumentStoreId, to name: String) throws {
        guard let desc = documents[id.id] else { return }
        documents[id.id] = DocumentStoreDescription(id: desc.id.id,
                                                    lastModified: desc.lastModified,
                                                    name: name,
                                                    thumbnail: desc.thumbnail,
                                                    root: desc.root)
    }

    func updateName(of id: DirectoryStoreId, to name: String) throws {
        guard let desc = directories[id.id] else { return }
        directories[id.id] = DirectoryStoreDescription(
            id: desc.id.id,
            created: desc.created,
            name: name,
            documents: desc.documentChildren,
            directories: desc.directoryChildren
        )
    }

    func updateLastModified(of file: DocumentStoreId, with date: Date) throws {
        guard let desc = documents[file.id] else { return }
        documents[file.id] = DocumentStoreDescription(id: desc.id.id,
                                                    lastModified: date,
                                                    name: desc.name,
                                                    thumbnail: desc.thumbnail,
                                                    root: desc.root)
    }

    func updatePreviewImage(of file: DocumentStoreId, with image: UIImage) throws {
        guard let desc = documents[file.id] else { return }
        documents[file.id] = DocumentStoreDescription(id: desc.id.id,
                                                    lastModified: desc.lastModified,
                                                    name: desc.name,
                                                    thumbnail: image,
                                                    root: desc.root)
    }

    func create(from description: DirectoryStoreDescription) throws {
        directories[description.id.id] = description

        for document in description.documentChildren {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directoryChildren {
            try self.append(directory: directory, to: description.id)
        }
    }

    func delete(child: DocumentStoreId, of: DirectoryStoreId) throws {
        documents.removeValue(forKey: child.id)
    }

    func delete(child: DirectoryStoreId, of: DirectoryStoreId) throws {
        guard let desc = directories[child.id] else { return }

        for document in desc.documentChildren {
            try self.delete(child: document.id, of: child)
        }

        for directory in desc.directoryChildren {
            try self.delete(child: directory.id, of: child)
        }

        directories.removeValue(forKey: child.id)
    }

    func reparent(from id: DirectoryStoreId, node: DocumentStoreId, to dest: DirectoryStoreId) throws {
        guard let doc = documents[node.id] else { return }
        guard let from = directories[id.id] else { return }
        guard let to = directories[dest.id] else { return }

        directories[from.id.id] = DirectoryStoreDescription(
            id: from.id.id,
            created: from.created,
            name: from.name,
            documents: from.documentChildren.filter { $0.id.id != node.id },
            directories: from.directoryChildren
        )

        directories[to.id.id] = DirectoryStoreDescription(
            id: to.id.id,
            created: to.created,
            name: to.name,
            documents: to.documentChildren + [doc],
            directories: from.directoryChildren
        )
    }

    func reparent(from id: DirectoryStoreId, node: DirectoryStoreId, to dest: DirectoryStoreId) throws {
        guard let dir = directories[node.id] else { return }
        guard let from = directories[id.id] else { return }
        guard let to = directories[dest.id] else { return }

        directories[from.id.id] = DirectoryStoreDescription(
            id: from.id.id,
            created: from.created,
            name: from.name,
            documents: from.documentChildren,
            directories: from.directoryChildren.filter { $0.id.id != node.id }
        )

        directories[to.id.id] = DirectoryStoreDescription(
            id: to.id.id,
            created: to.created,
            name: to.name,
            documents: to.documentChildren,
            directories: from.directoryChildren + [dir]
        )
    }

    func children(of parent: DirectoryStoreId) throws -> [FolderBrowserViewModel.Node] {
        guard let dir = directories[parent.id] else { return [] }
        let dirs = dir.directoryChildren.map { FolderBrowserViewModel.Node.from($0) }
        let docs = dir.documentChildren.map { FolderBrowserViewModel.Node.from($0) }
        return dirs + docs
    }

    func append(document description: DocumentStoreDescription, to id: DirectoryStoreId) throws {
        guard let desc = directories[id.id] else { return }
        documents[description.id.id] = description
        directories[id.id] = DirectoryStoreDescription(
            id: desc.id.id,
            created: desc.created,
            name: desc.name,
            documents: desc.documentChildren + [description],
            directories: desc.directoryChildren)

    }

    func append(directory description: DirectoryStoreDescription, to id: DirectoryStoreId) throws {
        guard let desc = directories[id.id] else { return }
        directories[id.id] = DirectoryStoreDescription(
            id: desc.id.id,
            created: desc.created,
            name: desc.name,
            documents: desc.documentChildren,
            directories: desc.directoryChildren + [description]
        )

        for document in description.documentChildren {
            try self.append(document: document, to: description.id)
        }

        for directory in description.directoryChildren {
            try self.append(directory: directory, to: description.id)
        }
    }
}
