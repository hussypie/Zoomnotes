//
//  DirectoryAccess+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import Combine

extension DirectoryAccessImpl {
    func stub(root: DirectoryStoreDescription) -> DirectoryAccessImpl {
        _ = self.root(from: root)
        return self
    }

    func stubF(root: DirectoryStoreDescription) -> AnyPublisher<Self, Error> {
        return self.root(from: root).map { _ in self }.eraseToAnyPublisher()
    }
}
