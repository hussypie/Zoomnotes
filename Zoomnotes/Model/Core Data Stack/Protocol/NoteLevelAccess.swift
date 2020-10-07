//
//  NoteLevelAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit
import UIKit

protocol NoteLevelAccess {
    func append(level description: NoteLevelDescription, to parent: UUID) throws
    func append(image description: NoteImageDescription, to parent: UUID) throws
    func remove(level id: UUID, from parent: UUID) throws
    func remove(image id: UUID, from parent: UUID) throws
    func read(level id: UUID) throws -> NoteLevelDescription?
    func read(image id: UUID) throws -> NoteImageDescription?
    func update(drawing: PKDrawing, for id: UUID) throws
    func update(preview: UIImage, for id: UUID) throws
    func update(preview: UIImage, image: UUID) throws
    func update(frame: CGRect, for id: UUID) throws
    func update(frame: CGRect, image: UUID) throws
    func update(annotation: PKDrawing, image: UUID) throws
}
