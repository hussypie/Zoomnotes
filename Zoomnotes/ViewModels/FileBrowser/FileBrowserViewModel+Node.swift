//
//  FileBrowserViewModel+Node.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension FolderBrowserViewModel {
    enum Node: Codable, Equatable {
        case directory(DirectoryVM)
        case file(FileVM)
        
        var id: UUID {
            switch self {
            case .directory(let dir):
                return dir.id
            case .file(let file):
                return file.id
            }
        }
        
        var name: String {
            switch self {
            case .directory(let dir):
                return dir.name
            case .file(let file):
                return file.name
            }
        }
        
        var date: Date {
            switch self {
            case .directory(let dir):
                return dir.created
            case .file(let file):
                return file.lastModified
            }
        }
        
        // swiftlint:disable:next nesting
        private enum CodingKeys: CodingKey {
            case rawValue
            case associatedValue
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawValue = try container.decode(Int.self, forKey: .rawValue)
            switch rawValue {
            case 0:
                let doc = try container.decode(DirectoryVM.self, forKey: .associatedValue)
                self = .directory(doc)
            case 1:
                let folder = try container.decode(FileVM.self, forKey: .associatedValue)
                self = .file(folder)
            default:
                fatalError("unknown coding key")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .directory(let dir):
                try container.encode(0, forKey: .rawValue)
                try container.encode(dir, forKey: .associatedValue)
            case .file(let file):
                try container.encode(1, forKey: .rawValue)
                try container.encode(file, forKey: .associatedValue)
            }
        }
    }
}

extension FolderBrowserViewModel.Node {
    static func from(_ description: DirectoryStoreDescription) -> FolderBrowserViewModel.Node {
        return .directory(DirectoryVM(id: UUID(),
                                      store: description.id,
                                      name: description.name,
                                      created: description.created))
    }
    
    static func from(_ description: DocumentStoreDescription) -> FolderBrowserViewModel.Node {
        return .file(FileVM(id: UUID(),
                            store: description.id,
                            preview: description.thumbnail,
                            name: description.name,
                            lastModified: description.lastModified))
    }
}
