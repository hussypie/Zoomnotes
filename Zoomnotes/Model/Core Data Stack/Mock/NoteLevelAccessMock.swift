//
//  NoteLevelAccessMock.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit
import UIKit

struct NoteLevelAccessMock: NoteLevelAccess {
    func create(from description: NoteLevelDescription) throws {
    }

    func delete(level id: UUID) throws {
    }

    func read(level id: UUID) throws -> NoteLevelDescription? {
        return nil
    }

    func update(drawing: PKDrawing, for id: UUID) throws {
    }

    func update(preview: CodableImage, for id: UUID) throws {
    }

    func update(frame: CGRect, for id: UUID) throws {
    }
}
