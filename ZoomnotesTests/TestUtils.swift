//
//  TestUtils.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 10. 18..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
@testable import Zoomnotes

extension FolderBrowserNode {
    func storeEquals(_ id: DirectoryID) -> Bool {
        switch self.store {
        case .directory(let did):
            return did == id
        default:
            return false
        }
    }

    func storeEquals(_ id: DocumentID) -> Bool {
        switch self.store {
        case .document(let fid):
            return fid == id
        default:
            return false
        }
    }
}
