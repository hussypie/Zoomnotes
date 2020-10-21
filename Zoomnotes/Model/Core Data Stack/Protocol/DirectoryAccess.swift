//
//  DirectoryAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 29..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine

protocol DirectoryAccess {
    func read(id dir: DirectoryID) -> AnyPublisher<DirectoryStoreLookupResult?, Error>
    func updateName(of id: DirectoryID, to name: String) -> AnyPublisher<Void, Error>
    func updateName(of id: DocumentID, to name: String) -> AnyPublisher<Void, Error>
    func root(from description: DirectoryStoreDescription) -> AnyPublisher<Void, Error>
    func delete(child: DirectoryID, of: DirectoryID) -> AnyPublisher<Void, Error>
    func delete(child: DocumentID, of: DirectoryID) -> AnyPublisher<Void, Error>
    func reparent(from id: DirectoryID, node: DirectoryID, to dest: DirectoryID) -> AnyPublisher<Void, Error>
    func reparent(from id: DirectoryID, node: DocumentID, to dest: DirectoryID) -> AnyPublisher<Void, Error>
    func children(of parent: DirectoryID) -> AnyPublisher<[FolderBrowserNode], Error>
    func append(document description: DocumentStoreDescription, to parent: DirectoryID) -> AnyPublisher<Void, Error>
    func append(directory description: DirectoryStoreDescription, to parent: DirectoryID) -> AnyPublisher<Void, Error>
    func noteModel(of id: DocumentID) -> AnyPublisher<DocumentLookupResult?, Error>
    func updateLastModified(of file: DocumentID, with date: Date) -> AnyPublisher<Void, Error>
    func updatePreviewImage(of file: DocumentID, with image: UIImage) -> AnyPublisher<Void, Error>
}
