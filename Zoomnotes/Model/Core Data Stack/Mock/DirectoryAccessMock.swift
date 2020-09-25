//
//  DirectoryAccessMock.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

class DirectoryAccessMock: DirectoryAccess {
    func delete(child: DirectoryAccessNode, of: UUID) throws {
    }

    func read(id: UUID) throws -> DirectoryVM? {
        return nil
    }

    func updateName(id: UUID, to name: String) throws {
    }

    func create(from description: DirectoryStoreDescription) throws {
    }

    func reparent(from id: UUID, node: DirectoryAccessNode, to dest: UUID) {
    }

    func children(of parent: UUID) throws -> [FolderBrowserViewModel.Node] {
        return []
    }

    func append(document description: DocumentStoreDescription, to id: UUID) throws {
    }

    func append(directory description: DirectoryStoreDescription, to id: UUID) throws {
    }
}
