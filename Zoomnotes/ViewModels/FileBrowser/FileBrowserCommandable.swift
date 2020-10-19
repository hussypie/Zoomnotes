//
//  FileBrowserCommandable.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 20..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

enum FileBrowserCommand {
    case createFile(preview: UIImage)
    case createDirectory
    case delete(FolderBrowserNode)
    case move(FolderBrowserNode, to: DirectoryID)
    case rename(FolderBrowserNode, to: String)
    case update(DocumentID, preview: UIImage)
}

protocol FileBrowserCommandable {
    func process(command: FileBrowserCommand)
}
