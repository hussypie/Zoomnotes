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
    func append(level description: NoteLevelDescription, to parent: NoteLevelID) throws
    func append(image description: NoteImageDescription, to parent: NoteLevelID) throws
    func remove(level id: NoteLevelID, from parent: NoteLevelID) throws
    func remove(image id: NoteImageID, from parent: NoteLevelID) throws
    func read(level id: NoteLevelID) throws -> NoteLevelDescription?
    func read(image id: NoteImageID) throws -> NoteImageDescription?
    func update(drawing: PKDrawing, for id: NoteLevelID) throws
    func update(preview: UIImage, for id: NoteLevelID) throws
    func update(preview: UIImage, image: NoteImageID) throws
    func update(frame: CGRect, for id: NoteLevelID) throws
    func update(frame: CGRect, image: NoteImageID) throws
    func update(annotation: PKDrawing, image: NoteImageID) throws
}
