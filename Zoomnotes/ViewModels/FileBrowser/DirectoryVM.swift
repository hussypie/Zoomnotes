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
    var name: String
    var created: Date

    required init(id: UUID, name: String, created: Date) {
        self.id = id
        self.name = name
        self.created = created
    }

    static func fresh(name: String, created: Date) -> DirectoryVM {
        return DirectoryVM(id: UUID(), name: name, created: created)
    }

    static var `default`: DirectoryVM {
        return DirectoryVM.fresh(name: "Documents", created: Date())
    }
}
