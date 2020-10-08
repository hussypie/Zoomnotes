//
//  DirectoryAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 29..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

protocol DirectoryAccess {
    func read(id dir: DirectoryStoreId) throws -> DirectoryStoreLookupResult?
    func updateName(of id: DirectoryStoreId, to name: String) throws
    func updateName(of id: DocumentStoreId, to name: String) throws
    func root(from description: DirectoryStoreDescription) throws
    func delete(child: DirectoryStoreId, of: DirectoryStoreId) throws
    func delete(child: DocumentStoreId, of: DirectoryStoreId) throws
    func reparent(from id: DirectoryStoreId, node: DirectoryStoreId, to dest: DirectoryStoreId) throws
    func reparent(from id: DirectoryStoreId, node: DocumentStoreId, to dest: DirectoryStoreId) throws
    func children(of parent: DirectoryStoreId) throws -> [FolderBrowserViewModel.Node]
    func append(document description: DocumentStoreDescription, to parent: DirectoryStoreId) throws
    func append(directory description: DirectoryStoreDescription, to parent: DirectoryStoreId) throws
    func noteModel(of id: DocumentStoreId) throws -> NoteLevelDescription?
    func updateLastModified(of file: DocumentStoreId, with date: Date) throws
    func updatePreviewImage(of file: DocumentStoreId, with image: UIImage) throws
}
