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
import Combine

class NoteLevelAccessMock: NoteLevelAccess {
    var db: [UUID: NoteLevelDescription]

    init(db: [UUID: NoteLevelDescription]) {
        self.db = db
    }

    func append(level description: NoteLevelDescription, to parent: UUID) throws {
        guard let desc = db[parent] else { return }
        db[desc.id] = NoteLevelDescription(preview: desc.preview,
                                           frame: desc.frame,
                                           id: desc.id,
                                           drawing: desc.drawing,
                                           sublevels: desc.sublevels + [description])
        db[description.id] = description

        for sublevel in description.sublevels {
            try self.append(level: sublevel, to: description.id)
        }

    }

    func remove(level id: UUID, from parent: UUID) throws {
        guard let desc = db[parent] else { return }
        guard let subject = db[id] else { return }

        for sublevel in subject.sublevels {
            try self.remove(level: sublevel.id, from: subject.id)
        }

        db[desc.id] = NoteLevelDescription(preview: desc.preview,
                                           frame: desc.frame,
                                           id: desc.id,
                                           drawing: desc.drawing,
                                           sublevels: desc.sublevels.filter { $0.id != id })

        db.removeValue(forKey: id)
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
        db[id] = NoteLevelDescription(preview: desc.preview,
                                      frame: desc.frame,
                                      id: desc.id,
                                      drawing: drawing,
                                      sublevels: desc.sublevels)
    }

    func update(preview: UIImage, for id: UUID) throws {
        guard let desc = db[id] else { return }
        db[id] = NoteLevelDescription(preview: preview,
                                      frame: desc.frame,
                                      id: desc.id,
                                      drawing: desc.drawing,
                                      sublevels: desc.sublevels)
    }

    func update(frame: CGRect, for id: UUID) throws {
        guard let desc = db[id] else { return }
        db[id] = NoteLevelDescription(preview: desc.preview,
                                      frame: frame,
                                      id: desc.id,
                                      drawing: desc.drawing,
                                      sublevels: desc.sublevels)
    }
}
