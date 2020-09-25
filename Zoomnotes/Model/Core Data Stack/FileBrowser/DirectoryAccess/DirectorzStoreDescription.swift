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
    let id: UUID
    let created: Date
    let name: String
    let documentChildren: [DocumentStoreDescription]
    let directoryChildren: [DirectoryStoreDescription]
}
