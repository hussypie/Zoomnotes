//
//  FileBrowserCommandable.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 20..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine

protocol FileBrowserCommandable {
    func createFile(id: DocumentID, name: String, preview: UIImage, lastModified: Date) -> AnyPublisher<Void, Error>
    func createFolder(id: DirectoryID, created: Date, name: String) -> AnyPublisher<Void, Error>
    func delete(node: FolderBrowserNode) -> AnyPublisher<Void, Error>
    func move(node: FolderBrowserNode, to dest: DirectoryID) -> AnyPublisher<Void, Error>
    func rename(node: FolderBrowserNode, to name: String) -> AnyPublisher<Void, Error>
    func update(doc: DocumentID, preview: UIImage) -> AnyPublisher<Void, Error>
}
