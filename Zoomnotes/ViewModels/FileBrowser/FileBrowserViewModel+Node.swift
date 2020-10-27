//
//  FileBrowserViewModel+Node.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

enum FolderBrowserNodeStoreID: Codable, Equatable {
    case directory(DirectoryID)
    case document(DocumentID)

    private enum CodingKeys: CodingKey {
        case rawValue
        case associatedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            let id = try container.decode(DirectoryID.self, forKey: .associatedValue)
            self = .directory(id)
        case 1:
            let id = try container.decode(DocumentID.self, forKey: .associatedValue)
            self = .document(id)
        default:
            fatalError("unknown coding key")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .directory(let id):
            try container.encode(0, forKey: .rawValue)
            try container.encode(id, forKey: .associatedValue)
        case .document(let id):
            try container.encode(1, forKey: .rawValue)
            try container.encode(id, forKey: .associatedValue)
        }
    }
}

class FolderBrowserNode: Codable {
    let id: UUID
    let store: FolderBrowserNodeStoreID
    var preview: CodableImage
    var name: String
    var lastModified: Date

    init(id: UUID,
         store: FolderBrowserNodeStoreID,
         preview: CodableImage,
         name: String,
         lastModified: Date
    ) {
        self.id = id
        self.store = store
        self.preview = preview
        self.name = name
        self.lastModified = lastModified
    }
}

extension FolderBrowserNode {
    static func from(_ description: DirectoryStoreDescription) -> FolderBrowserNode {
        return FolderBrowserNode(id: UUID(),
                                 store: .directory(description.id),
                                 preview: CodableImage(wrapping: UIImage(named: "folder")!),
                                 name: description.name,
                                 lastModified: description.created)
    }
    
    static func from(_ description: DocumentStoreDescription) -> FolderBrowserNode {
        return FolderBrowserNode(id: UUID(),
                                 store: .document(description.id),
                                 preview: CodableImage(wrapping: description.thumbnail),
                                 name: description.name,
                                 lastModified: description.lastModified)
    }
}
