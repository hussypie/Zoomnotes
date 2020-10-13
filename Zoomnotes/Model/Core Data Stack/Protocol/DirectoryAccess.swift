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
    func read(id dir: DirectoryID) throws -> DirectoryStoreLookupResult?
    func updateName(of id: DirectoryID, to name: String) throws
    func updateName(of id: DocumentID, to name: String) throws
    func root(from description: DirectoryStoreDescription) throws
    func delete(child: DirectoryID, of: DirectoryID) throws
    func delete(child: DocumentID, of: DirectoryID) throws
    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) throws
    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) throws
    func children(of parent: DirectoryID) throws -> [FolderBrowserViewModel.Node]
    func append(document description: DocumentStoreDescription, to parent: DirectoryID) throws
    func append(directory description: DirectoryStoreDescription, to parent: DirectoryID) throws
    func noteModel(of id: DocumentID) throws -> NoteLevelDescription?
    func updateLastModified(of file: DocumentID, with date: Date) throws
    func updatePreviewImage(of file: DocumentID, with image: UIImage) throws
}
