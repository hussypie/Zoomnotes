//
//  NoteLevelAccessMock.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit
import Combine
import UIKit

class NoteLevelAccessMock: NoteLevelAccess {
    typealias LevelTable = [NoteLevelID: NoteLevelDescription]
    typealias ImageTable = [NoteImageID: NoteImageDescription]

    var levels: LevelTable
    var images: ImageTable

    var levelDrawer: LevelTable = [:]
    var imageDrawer: ImageTable = [:]

    var levelTrash: LevelTable = [:]
    var imageTrash: ImageTable = [:]

    init(levels: LevelTable, images: ImageTable) {
        self.levels = levels
        self.images = images
    }

    func append(level description: NoteLevelDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[parent] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                               frame: desc.frame,
                                               id: desc.id,
                                               drawing: desc.drawing,
                                               sublevels: desc.sublevels + [description],
                                               images: desc.images)
        levels[description.id] = description

        for sublevel in description.sublevels {
            _ = self.append(level: sublevel, to: description.id)
        }

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func append(image description: NoteImageDescription, to parent: NoteLevelID)  -> AnyPublisher<Void, Error> {
        guard let desc = levels[parent] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                               frame: desc.frame,
                                               id: desc.id,
                                               drawing: desc.drawing,
                                               sublevels: desc.sublevels,
                                               images: desc.images + [description])
        images[description.id] = description
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func remove(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[parent] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        guard let subject = levels[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }

        for sublevel in subject.sublevels {
            _ = self.remove(level: sublevel.id, from: subject.id)
        }

        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                               frame: desc.frame,
                                               id: desc.id,
                                               drawing: desc.drawing,
                                               sublevels: desc.sublevels.filter { $0.id != id },
                                               images: desc.images)

        levels.removeValue(forKey: id)
        levelTrash[id] = subject

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func remove(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[parent] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }

        levels[desc.id] = NoteLevelDescription(preview: desc.preview,
                                               frame: desc.frame,
                                               id: desc.id,
                                               drawing: desc.drawing,
                                               sublevels: desc.sublevels,
                                               images: desc.images.filter { $0.id != id })

        let subject = images[id]
        images.removeValue(forKey: id)
        imageTrash[id] = subject

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func delete(level id: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        for sublevel in desc.sublevels {
            // swiftlint:disable:next force_try
            _ = self.delete(level: sublevel.id)
        }
        levels.removeValue(forKey: id)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func read(level id: NoteLevelID) -> AnyPublisher<NoteLevelDescription?, Error> {
        return Future { $0(.success(self.levels[id])) }.eraseToAnyPublisher()
    }

    func read(image id: NoteImageID) -> AnyPublisher<NoteImageDescription?, Error> {
        return Future { $0(.success(self.images[id])) }.eraseToAnyPublisher()
    }

    func update(drawing: PKDrawing, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        levels[id] = NoteLevelDescription(preview: desc.preview,
                                          frame: desc.frame,
                                          id: desc.id,
                                          drawing: drawing,
                                          sublevels: desc.sublevels,
                                          images: desc.images)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func update(annotation: PKDrawing, image: NoteImageID) -> AnyPublisher<Void, Error> {
        guard let desc = images[image] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        images[desc.id] = NoteImageDescription(id: desc.id,
                                               preview: desc.image,
                                               drawing: annotation,
                                               image: desc.image,
                                               frame: desc.frame)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func update(preview: UIImage, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        levels[id] = NoteLevelDescription(preview: preview,
                                          frame: desc.frame,
                                          id: desc.id,
                                          drawing: desc.drawing,
                                          sublevels: desc.sublevels,
                                          images: desc.images)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func update(preview: UIImage, image: NoteImageID) -> AnyPublisher<Void, Error> {
        guard let desc = images[image] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        images[desc.id] = NoteImageDescription(id: desc.id,
                                               preview: preview,
                                               drawing: desc.drawing,
                                               image: desc.image,
                                               frame: desc.frame)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func update(frame: CGRect, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        guard let desc = levels[id] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        levels[id] = NoteLevelDescription(preview: desc.preview,
                                          frame: frame,
                                          id: desc.id,
                                          drawing: desc.drawing,
                                          sublevels: desc.sublevels,
                                          images: desc.images)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func update(frame: CGRect, image: NoteImageID) -> AnyPublisher<Void, Error> {
        guard let desc = images[image] else { return Future { $0(.success(())) }.eraseToAnyPublisher() }
        images[desc.id] = NoteImageDescription(id: desc.id,
                                               preview: desc.preview,
                                               drawing: desc.drawing,
                                               image: desc.image,
                                               frame: frame)
        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func emptyTrash() -> AnyPublisher<Void, Error> {
        self.levelTrash.removeAll()
        self.imageTrash.removeAll()

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func moveToDrawer(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        let desc = levels[parent]!
        levels[parent] = NoteLevelDescription(preview: desc.preview,
                                              frame: desc.frame,
                                              id: desc.id,
                                              drawing: desc.drawing,
                                              sublevels: desc.sublevels,
                                              images: desc.images.filter { $0.id != id })

        imageDrawer[id] = images[id]!
        images.removeValue(forKey: id)

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func moveToDrawer(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        let desc = levels[parent]!
        levels[parent] = NoteLevelDescription(preview: desc.preview,
                                              frame: desc.frame,
                                              id: desc.id,
                                              drawing: desc.drawing,
                                              sublevels: desc.sublevels.filter { $0.id != id },
                                              images: desc.images)

        levelDrawer[id] = levels[id]!
        levels.removeValue(forKey: id)

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func moveFromDrawer(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        let image = imageDrawer[id]!
        let desc = levels[parent]!
        levels[parent] = NoteLevelDescription(preview: desc.preview,
                                              frame: desc.frame,
                                              id: desc.id,
                                              drawing: desc.drawing,
                                              sublevels: desc.sublevels,
                                              images: desc.images + [image])

        imageDrawer.removeValue(forKey: id)

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func moveFromDrawer(level id: NoteLevelID, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        let level = levelDrawer[id]!
        let desc = levels[parent]!
        levels[parent] = NoteLevelDescription(preview: desc.preview,
                                              frame: desc.frame,
                                              id: desc.id,
                                              drawing: desc.drawing,
                                              sublevels: desc.sublevels + [level],
                                              images: desc.images)

        levelDrawer.removeValue(forKey: id)

        return Future { $0(.success(())) }.eraseToAnyPublisher()
    }

    func restore(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<SubImageDescription, Error> {
        let image = imageDrawer[id]!
        let desc = levels[parent]!
        levels[parent] = NoteLevelDescription(preview: desc.preview,
                                              frame: desc.frame,
                                              id: desc.id,
                                              drawing: desc.drawing,
                                              sublevels: desc.sublevels,
                                              images: desc.images + [image])

        imageTrash.removeValue(forKey: id)
        let subDesc = SubImageDescription(id: image.id,
                                          preview: image.preview,
                                          frame: image.frame)

        return Future { $0(.success(subDesc)) }.eraseToAnyPublisher()
    }

    func restore(level id: NoteLevelID, to parent: NoteLevelID) -> AnyPublisher<SublevelDescription, Error> {
        let level = levelTrash[id]!
        let desc = levels[parent]!
        levels[parent] = NoteLevelDescription(preview: desc.preview,
                                              frame: desc.frame,
                                              id: desc.id,
                                              drawing: desc.drawing,
                                              sublevels: desc.sublevels + [level],
                                              images: desc.images)

        levelTrash.removeValue(forKey: id)
        let subdesc = SublevelDescription(id: level.id,
                                          preview: level.preview,
                                          frame: level.frame)

        return Future { $0(.success(subdesc)) }.eraseToAnyPublisher()
    }
}
