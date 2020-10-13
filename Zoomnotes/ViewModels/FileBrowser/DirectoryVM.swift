//
//  DirectoryVM.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class DirectoryVM: NSObject, Codable {
    let id: UUID
    let store: DirectoryID
    var name: String
    var created: Date

    required init(id: UUID, store: DirectoryID, name: String, created: Date) {
        self.id = id
        self.store = store
        self.name = name
        self.created = created
    }
}
