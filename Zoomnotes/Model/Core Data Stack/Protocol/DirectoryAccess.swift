//
//  DirectoryAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

enum DirectoryAccessNode {
    case document(UUID)
    case directory(UUID)

    var id: UUID {
        switch self {
        case .document(let id):
            return id
        case .directory(let id):
            return id
        }
    }
}

protocol DirectoryAccess {
    func read(id: UUID) throws -> DirectoryVM?
    func updateName(id: UUID, to name: String) throws
    func create(from description: DirectoryStoreDescription) throws
    func delete(child: DirectoryAccessNode, of: UUID) throws
    func reparent(from id: UUID, node: DirectoryAccessNode, to dest: UUID) throws
    func children(of parent: UUID) throws -> [FolderBrowserViewModel.Node]
    func append(document description: DocumentStoreDescription, to id: UUID) throws
    func append(directory description: DirectoryStoreDescription, to id: UUID) throws
}
