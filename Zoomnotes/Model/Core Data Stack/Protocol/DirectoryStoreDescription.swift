//
//  DirectorzStoreDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

struct DirectoryStoreDescription {
    let id: DirectoryID
    let created: Date
    let name: String
    let documents: [DocumentStoreDescription]
    let directories: [DirectoryStoreDescription]
}
