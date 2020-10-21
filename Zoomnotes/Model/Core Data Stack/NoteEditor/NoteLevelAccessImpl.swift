//
//  NoteModelAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 19..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import CoreData
import PencilKit
import Combine
import UIKit

struct NoteLevelAccessImpl: NoteLevelAccess {
    let access: DBAccess
    let document: DocumentID

    enum AccessError: Error {
        case cannotCreateRectStore
        case cannotCreateLevelStore
        case cannotCreateImageStore
        case cannotFindReferencedEntity
        case cannotGetImageTrash
        case cannotGetSubimages
        case cannotGetSublevels
    }

    func append(level description: NoteLevelDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).flatMap { rect in
            return self.access.build(id: description.id, prepare: { (entity: NoteLevelStore) -> NoteLevelStore in
                entity.preview = description.preview.pngData()!
                entity.frame = rect
                entity.drawing = description.drawing.dataRepresentation()

                return entity
            })
        }.flatMap { sublevel in
            return self.access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) -> Void in
                guard let store = store else { throw AccessError.cannotCreateLevelStore }
                guard let sublevel = sublevel else { throw AccessError.cannotCreateLevelStore }
                store.addToSublevels(sublevel)
            }
        }.flatMap { _ in
            Publishers.Sequence(sequence: description.sublevels)
                .flatMap { sublevel in self.append(level: sublevel, to: description.id) }
                .collect()
        }.map { _ in return }.eraseToAnyPublisher()
    }

    func append(image description: NoteImageDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
       return access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            return store
        }).flatMap { rect in
            return self.access.build(id: description.id, prepare: { (store: ImageStore) -> ImageStore in
                store.frame = rect
                store.drawingAnnotation = description.drawing.dataRepresentation()
                store.image = description.image.pngData()!
                store.preview = description.image.pngData()!

                return store
            })
        }.flatMap { image in
            self.access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
                guard let store = store else { throw AccessError.cannotCreateImageStore }
                guard let image = image else { throw AccessError.cannotCreateImageStore }
                store.addToImages(image)
            }
       }.eraseToAnyPublisher()
    }

    func remove(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        return access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else {
                throw AccessError.cannotFindReferencedEntity
            }
            guard let sublevels = store.sublevels as? Set<NoteLevelStore> else {
                throw AccessError.cannotGetSublevels
            }
            guard let child = sublevels.first(where: { $0.id! == id }) else {
                throw AccessError.cannotFindReferencedEntity
            }

            store.removeFromSublevels(child)
            return child
        }.flatMap { (store: NoteLevelStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
                noteStore.addToTrash(store)
            }
        }.eraseToAnyPublisher()
    }

    func remove(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else { throw AccessError.cannotFindReferencedEntity }
            guard let images = store.images as? Set<ImageStore> else { throw AccessError.cannotGetSubimages }
            guard let subject = images.first(where: { $0.id! == id }) else { throw AccessError.cannotFindReferencedEntity }

            store.removeFromImages(subject)
            return subject
        }.flatMap { (store: ImageStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
                noteStore.addToImageTrash(store)
            }
        }.eraseToAnyPublisher()
    }

    func restore(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<SubImageDescription, Error> {
        access.accessing(to: .read, id: id) { (imageStore: ImageStore?) in
            guard let imageStore = imageStore else { throw AccessError.cannotFindReferencedEntity }
            return imageStore
        }.flatMap { (imageStore: ImageStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    throw AccessError.cannotFindReferencedEntity
                }

                noteStore.removeFromImageTrash(imageStore)

                return imageStore
            }
        }.map { (imageStore: ImageStore) in
            SubImageDescription(id: ID(imageStore.id!),
                                preview: UIImage(data: imageStore.preview!)!,
                                frame: CGRect.from(imageStore.frame!))
        }
        .eraseToAnyPublisher()

    }

    func restore(level id: NoteLevelID, to parent: NoteLevelID) -> AnyPublisher<SublevelDescription, Error> {
        access.accessing(to: .read, id: id) { (levelStore: NoteLevelStore?) in
            guard let levelStore = levelStore else { throw AccessError.cannotFindReferencedEntity }
            return levelStore
        }.flatMap { (levelStore: NoteLevelStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    throw AccessError.cannotFindReferencedEntity
                }
                noteStore.removeFromTrash(levelStore)
                return levelStore
            }
        }.map { (levelStore: NoteLevelStore) in
            SublevelDescription(id: ID(levelStore.id!),
                                preview: UIImage(data: levelStore.preview!)!,
                                frame: CGRect.from(levelStore.frame!))

        }.eraseToAnyPublisher()
    }

    func read(level id: NoteLevelID) -> AnyPublisher<NoteLevelDescription?, Error> {
        access.accessing(to: .read, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return nil }

            return try NoteLevelDescription.from(store: store)
        }.eraseToAnyPublisher()
    }

    func read(image id: NoteImageID) -> AnyPublisher<NoteImageDescription?, Error> {
        access.accessing(to: .read, id: id) { (store: ImageStore?) in
            guard let store = store else { return nil }
            guard let preview = UIImage(data: store.preview!) else { return nil }
            guard let image = UIImage(data: store.image!) else { return nil }
            guard let drawing = try? PKDrawing(data: store.drawingAnnotation!) else { return nil }

            return NoteImageDescription(id: ID(store.id!),
                                        preview: preview,
                                        drawing: drawing,
                                        image: image,
                                        frame: CGRect.from(store.frame!))
        }
    }

    func update(drawing: PKDrawing, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.drawing = drawing.dataRepresentation()
        }
    }

    func update(annotation: PKDrawing, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.drawingAnnotation = annotation.dataRepresentation()
        }
    }

    func update(preview: UIImage, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(preview: UIImage, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else { return }
            store.preview = preview.pngData()!
        }
    }

    func update(frame: CGRect, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }).flatMap { rect in
            self.access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
                guard let store = store else { return }
                store.frame = rect
            }
        }.eraseToAnyPublisher()
    }

    func update(frame: CGRect, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(frame.minX)
            store.y = Float(frame.minY)
            store.width = Float(frame.width)
            store.height = Float(frame.height)

            return store
        }).flatMap { rect in
            self.access.accessing(to: .write, id: image) { (store: ImageStore?) in
                guard let store = store else { return }
                store.frame = rect
            }
        }.eraseToAnyPublisher()
    }

    func emptyTrash() -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: document) { (noteStore: NoteStore?) in
            guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
            guard let imageDrawer = noteStore.imageDrawer as? Set<ImageStore> else { return }
            imageDrawer.forEach { self.access.delete($0) }

            guard let levelDrawer = noteStore.drawer as? Set<NoteLevelStore> else { return }
            levelDrawer.forEach { self.access.delete($0) }
        }
    }

    func moveToDrawer(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .read, id: id) { (imageStore: ImageStore?) -> ImageStore in
            guard let imageStore = imageStore else { throw AccessError.cannotFindReferencedEntity }
            return imageStore
        }.flatMap { (imageStore: ImageStore) -> AnyPublisher<ImageStore, Error> in
            self.access.accessing(to: .write, id: parent) { (noteStore: NoteLevelStore?) in
                guard let note = noteStore else { throw AccessError.cannotFindReferencedEntity }
                note.removeFromImages(imageStore)
                return imageStore
            }
        }.flatMap { (imageStore: ImageStore) -> AnyPublisher<Void, Error> in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
                noteStore.addToImageDrawer(imageStore)
            }
        }.eraseToAnyPublisher()
    }

    func moveToDrawer(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .read, id: id) { (levelStore: NoteLevelStore?) -> NoteLevelStore in
            guard let levelStore = levelStore else { throw AccessError.cannotFindReferencedEntity }
            return levelStore
        }.flatMap { (levelStore: NoteLevelStore) -> AnyPublisher<NoteLevelStore, Error> in
            self.access.accessing(to: .write, id: parent) { (noteStore: NoteLevelStore?) in
                guard let note = noteStore else { throw AccessError.cannotFindReferencedEntity }
                note.removeFromSublevels(levelStore)
                return levelStore
            }
        }.flatMap { (levelStore: NoteLevelStore) -> AnyPublisher<Void, Error> in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
                noteStore.addToDrawer(levelStore)
            }
        }.eraseToAnyPublisher()
    }

    func moveFromDrawer(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .read, id: id) { (imageStore: ImageStore?) in
            guard let imageStore = imageStore else { throw AccessError.cannotFindReferencedEntity }
            return imageStore
        }.flatMap { (imageStore: ImageStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
                noteStore.removeFromImageDrawer(imageStore)
                return imageStore
            }
        }.flatMap { (imageStore: ImageStore) in
            self.access.accessing(to: .write, id: parent) { (noteLevel: NoteLevelStore?) in
                guard let noteLevelStore = noteLevel else { throw AccessError.cannotFindReferencedEntity }
                noteLevelStore.addToImages(imageStore)
            }
        }.eraseToAnyPublisher()
    }

    func moveFromDrawer(level id: NoteLevelID, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .read, id: id) { (levelStore: NoteLevelStore?) in
            guard let levelStore = levelStore else { throw AccessError.cannotFindReferencedEntity }
            return levelStore
        }.flatMap { (levelStore: NoteLevelStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else { throw AccessError.cannotFindReferencedEntity }
                noteStore.removeFromDrawer(levelStore)
                return levelStore
            }
        }.flatMap { (levelStore: NoteLevelStore) in
            self.access.accessing(to: .write, id: parent) { (noteLevel: NoteLevelStore?) in
                guard let noteLevelStore = noteLevel else { throw AccessError.cannotFindReferencedEntity }
                noteLevelStore.addToSublevels(levelStore)
            }
        }.eraseToAnyPublisher()
    }
}
