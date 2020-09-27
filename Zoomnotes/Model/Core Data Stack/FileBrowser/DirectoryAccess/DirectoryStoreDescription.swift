//
//  DirectorzStoreDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

struct DirectoryStoreId: Equatable {
    let id: UUID
}

struct DirectoryStoreDescription {
    let id: DirectoryStoreId
    let created: Date
    let name: String
    let documentChildren: [DocumentStoreDescription]
    let directoryChildren: [DirectoryStoreDescription]

    init(id: UUID,
         created: Date,
         name: String,
         documents: [DocumentStoreDescription],
         directories: [DirectoryStoreDescription]
    ) {
        self.id = DirectoryStoreId(id: id)
        self.created = created
        self.name = name
        self.documentChildren = documents
        self.directoryChildren = directories
    }
}
