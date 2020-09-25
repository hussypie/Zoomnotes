//
//  DocumentStoreDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

struct DocumentStoreDescription {
    let data: String
    let id: UUID
    let lastModified: Date
    let name: String
    let thumbnail: UIImage
}
