//
//  NoteLevelDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit

struct NoteLevelDescription {
    let parent: UUID?
    let preview: Data
    let frame: CGRect
    let id: UUID
    let drawing: PKDrawing
}
