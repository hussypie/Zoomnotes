//
//  FileVM.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class FileVM: NSObject, Codable {
    let id: UUID
    let store: DocumentID
    var preview: CodableImage
    var name: String
    var lastModified: Date

    required init(
        id: UUID,
        store: DocumentID,
        preview: UIImage,
        name: String,
        lastModified: Date
    ) {
        self.id = id
        self.store = store
        self.preview = CodableImage(wrapping: preview)
        self.name = name
        self.lastModified = lastModified
    }
}
