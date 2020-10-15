//
//  DirectoryAccess+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

extension DirectoryAccessImpl {
    func stub(root: DirectoryStoreDescription) -> DirectoryAccessImpl {
        // swiftlint:disable:next force_try
        self.root(from: root)
        return self
    }
}
