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
    var levels: [UUID: NoteLevelDescription]
    var images: [UUID: NoteImageDescription]

    init(levels: [UUID: NoteLevelDescription], images: [UUID: NoteImageDescription]) {
        self.levels = levels
        self.images = images
    }

    func append(level description: NoteLevelDescription, to parent: UUID) throws {
        guard let desc = levels[parent] else { return }
        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                           frame: desc.frame,
                                           id: desc.id,
                                           drawing: desc.drawing,
                                           sublevels: desc.sublevels + [description],
                                           images: desc.images)
        levels[description.id] = description

        for sublevel in description.sublevels {
            try self.append(level: sublevel, to: description.id)
        }
    }

    func append(image description: NoteImageDescription, to parent: UUID) throws {
        guard let desc = levels[parent] else { return }
        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                           frame: desc.frame,
                                           id: desc.id,
                                           drawing: desc.drawing,
                                           sublevels: desc.sublevels,
                                           images: desc.images + [description])
        images[description.id] = description
    }

    func remove(level id: UUID, from parent: UUID) throws {
        guard let desc = levels[parent] else { return }
        guard let subject = levels[id] else { return }

        for sublevel in subject.sublevels {
            try self.remove(level: sublevel.id, from: subject.id)
        }

        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                           frame: desc.frame,
                                           id: desc.id,
                                           drawing: desc.drawing,
                                           sublevels: desc.sublevels.filter { $0.id != id },
                                           images: desc.images)

        levels.removeValue(forKey: id)
    }

    func remove(image id: UUID, from parent: UUID) throws {
        guard let desc = levels[parent] else { return }

        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                           frame: desc.frame,
                                           id: desc.id,
                                           drawing: desc.drawing,
                                           sublevels: desc.sublevels,
                                           images: desc.images.filter { $0.id != id })

        images.removeValue(forKey: id)
    }

    func delete(level id: UUID) throws {
        guard let desc = levels[id] else { return }
        for sublevel in desc.sublevels {
            // swiftlint:disable:next force_try
            try! self.delete(level: sublevel.id)
        }
        levels.removeValue(forKey: id)
    }

    func read(level id: UUID) throws -> NoteLevelDescription? {
        return levels[id]
    }

    func update(drawing: PKDrawing, for id: UUID) throws {
        guard let desc = levels[id] else { return }
        levels[id] = NoteLevelDescription(preview: desc.preview,
                                      frame: desc.frame,
                                      id: desc.id,
                                      drawing: drawing,
                                      sublevels: desc.sublevels,
                                      images: desc.images)
    }

    func update(annotation: PKDrawing, image: UUID) throws {
        guard let desc = images[image] else { return }
        images[desc.id] = NoteImageDescription(id: desc.id,
                                               preview: desc.image,
                                               drawing: annotation,
                                               image: desc.image,
                                               frame: desc.frame)
    }

    func update(preview: UIImage, for id: UUID) throws {
        guard let desc = levels[id] else { return }
        levels[id] = NoteLevelDescription(preview: preview,
                                      frame: desc.frame,
                                      id: desc.id,
                                      drawing: desc.drawing,
                                      sublevels: desc.sublevels,
                                      images: desc.images)
    }

    func update(frame: CGRect, for id: UUID) throws {
        guard let desc = levels[id] else { return }
        levels[id] = NoteLevelDescription(preview: desc.preview,
                                      frame: frame,
                                      id: desc.id,
                                      drawing: desc.drawing,
                                      sublevels: desc.sublevels,
                                      images: desc.images)
    }

    func update(frame: CGRect, image: UUID) throws {
        guard let desc = images[image] else { return }
        images[desc.id] = NoteImageDescription(id: desc.id,
                                               preview: desc.image,
                                               drawing: desc.drawing,
                                               image: desc.image,
                                               frame: frame)
    }
}
