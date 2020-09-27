//
//  DocumentStoreDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

struct DocumentStoreId: Equatable {
    let id: UUID
}

struct DocumentStoreDescription {
    let id: DocumentStoreId
    let lastModified: Date
    let name: String
    let thumbnail: UIImage
    let root: NoteLevelDescription

    init(id: UUID, lastModified: Date, name: String, thumbnail: UIImage, root: NoteLevelDescription) {
        self.id = DocumentStoreId(id: id)
        self.lastModified = lastModified
        self.name = name
        self.thumbnail = thumbnail
        self.root = root
    }
}
