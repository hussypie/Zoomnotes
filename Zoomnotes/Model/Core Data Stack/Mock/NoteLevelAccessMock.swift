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

class NoteLevelAccessMock: NoteLevelAccess {
    var db: [UUID: NoteLevelDescription]

    init(db: [UUID: NoteLevelDescription]) { self.db = db }

    func create(from description: NoteLevelDescription) throws {
        db[description.id] = description
        for sublevel in description.sublevels {
            // swiftlint:disable:next force_try
            try! self.create(from: sublevel)
        }
    }

    func delete(level id: UUID) throws {
        guard let desc = db[id] else { return }
        for sublevel in desc.sublevels {
            // swiftlint:disable:next force_try
            try! self.delete(level: sublevel.id)
        }
        db.removeValue(forKey: id)
    }

    func read(level id: UUID) throws -> NoteLevelDescription? {
        return db[id]
    }

    func update(drawing: PKDrawing, for id: UUID) throws {
        guard let desc = db[id] else { return }
        db[id] = NoteLevelDescription(parent: desc.parent,
                                      preview: desc.preview,
                                      frame: desc.frame,
                                      id: desc.id,
                                      drawing: drawing,
                                      sublevels: desc.sublevels)
    }

    func update(preview: CodableImage, for id: UUID) throws {
        guard let desc = db[id] else { return }
        db[id] = NoteLevelDescription(parent: desc.parent,
                                      preview: preview.image.pngData()!,
                                      frame: desc.frame,
                                      id: desc.id,
                                      drawing: desc.drawing,
                                      sublevels: desc.sublevels)
    }

    func update(frame: CGRect, for id: UUID) throws {
        guard let desc = db[id] else { return }
        db[id] = NoteLevelDescription(parent: desc.parent,
                                      preview: desc.preview,
                                      frame: frame,
                                      id: desc.id,
                                      drawing: desc.drawing,
                                      sublevels: desc.sublevels)
    }
}
