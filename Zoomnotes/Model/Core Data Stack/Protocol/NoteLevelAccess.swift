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
import Combine

protocol NoteLevelAccess {
    func create(from description: NoteLevelDescription) throws
    func delete(level id: UUID) throws
    func read(level id: UUID) throws -> NoteLevelDescription?
    func update(drawing: PKDrawing, for id: UUID) throws
    func update(preview: UIImage, for id: UUID) throws
    func update(frame: CGRect, for id: UUID) throws

    var previewSubject: PassthroughSubject<(UUID, UIImage), Never> { get }
}
