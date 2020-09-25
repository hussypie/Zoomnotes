//
//  CoreDataAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData
import UIKit

struct CoreDataAccess {
    let directory: DirectoryAccess
    let file: DocumentAccess
}

extension CoreDataAccess {
    func stub(root: DirectoryStoreDescription) -> Self {
        // swiftlint:disable:next force_try
        try! self.directory.create(from: root)
        return self
    }
}
