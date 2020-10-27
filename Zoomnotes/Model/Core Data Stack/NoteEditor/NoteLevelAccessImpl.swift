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
    let logger: LoggerProtocol

    enum AccessError: Error {
        case cannotCreateRectStore
        case cannotCreateLevelStore
        case cannotCreateImageStore
        case cannotFindReferencedEntity
        case cannotGetImageTrash
        case cannotGetLevelTrash
        case cannotGetSubimages
        case cannotGetSublevels
    }

    func sublevel(from description: NoteLevelDescription) -> AnyPublisher<NoteLevelStore?, Error> {
        logger.info("Building sublevel, id: \(description.id)")
        return access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            self.logger.info("Building frame for sublevel id: \(description.id)")
            return store
        }).flatMap { rect in
            self.access.build(id: description.id, prepare: { (entity: NoteLevelStore) -> NoteLevelStore in
                entity.preview = description.preview.pngData()!
                entity.frame = rect
                entity.drawing = description.drawing.dataRepresentation()

                self.logger.info("Building sublevel record, id: \(description.id)")

                return entity
            })
        }.eraseToAnyPublisher()
    }

    func subimage(from description: NoteImageDescription) -> AnyPublisher<ImageStore?, Error> {
        logger.info("Building subimage, id: \(description.id)")
        return access.build(prepare: { (store: RectStore) -> RectStore in
            store.x = Float(description.frame.minX)
            store.y = Float(description.frame.minY)
            store.width = Float(description.frame.width)
            store.height = Float(description.frame.height)

            self.logger.info("Building subimage for sublevel id: \(description.id)")

            return store
        }).flatMap { [access] rect in
            access.build(id: description.id, prepare: { (store: ImageStore) -> ImageStore in
                store.frame = rect
                store.drawingAnnotation = description.drawing.dataRepresentation()
                store.image = description.image.pngData()!
                store.preview = description.image.pngData()!

                self.logger.info("Building subimage record, id: \(description.id)")

                return store
            })
        }.eraseToAnyPublisher()
    }

    func append(level description: NoteLevelDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        logger.info("Append level (id: \(description.id)) to level id: \(parent)")
        return sublevel(from: description)
            .flatMap { sublevel in
            return self.access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) -> Void in
                guard let store = store else {
                    self.logger.warning("Parent store (id: \(parent)) not found in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                guard let sublevel = sublevel else {
                    self.logger.warning("Sublevel (id: \(description.id)) was not created successfully")
                    throw AccessError.cannotCreateLevelStore
                }
                store.addToSublevels(sublevel)

                self.logger.info("Appended level (id: \(description.id)) to sublevels of level id: \(parent)")
            }
        }.flatMap { _ -> AnyPublisher<Void, Error> in
            self.logger.info("Appening sublevels and subimages to level (id: \(description.id))")
            return Publishers.Zip(
                Publishers.Sequence(sequence: description.sublevels)
                    .flatMap { sublevel in self.append(level: sublevel, to: description.id) }
                    .collect(),
                Publishers.Sequence(sequence: description.images)
                    .flatMap { subimage in self.append(image: subimage, to: description.id) }
                    .collect()
                ).map { _ in return }.eraseToAnyPublisher()
        }.map { _ in
            self.logger.info("Appended level (id: \(description.id)) and its children to sublevels of level id: \(parent)")
            return
        }.eraseToAnyPublisher()
    }

    func append(image description: NoteImageDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        self.logger.info("Append subimage (id: \(description.id)) to parent (id: \(parent))")
        return subimage(from: description)
            .flatMap { image in
            self.access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
                guard let store = store else {
                    self.logger.warning("Parent store (id: \(parent)) not found in db")
                    throw AccessError.cannotCreateImageStore
                }
                guard let image = image else {
                    self.logger.warning("Subimage (id: \(description.id)) was not created successfully")
                    throw AccessError.cannotCreateImageStore
                }
                store.addToImages(image)
                self.logger.info("Appended subimage (id: \(description.id)) to parent (id: \(parent))")
            }
       }.eraseToAnyPublisher()
    }

    func remove(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        return access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find parent level (id: \(parent) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            guard let sublevels = store.sublevels as? Set<NoteLevelStore> else {
                self.logger.warning("Cannot get sublevels of parent (id: \(parent)")
                throw AccessError.cannotGetSublevels
            }
            guard let child = sublevels.first(where: { $0.id! == id }) else {
                self.logger.warning("Cannot find child (id: \(id)) among sublevels")
                throw AccessError.cannotFindReferencedEntity
            }

            store.removeFromSublevels(child)
            self.logger.info("Removed child (id: \(id)) from children")
            return child
        }.flatMap { (store: NoteLevelStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    self.logger.warning("Cannot find document (id: \(self.document)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                noteStore.addToTrash(store)
                self.logger.info("Added child (id: \(id)) to trash of parent: \(self.document)")
            }
        }.eraseToAnyPublisher()
    }

    func remove(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: parent) { (store: NoteLevelStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find parent level (id: \(parent) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            guard let images = store.images as? Set<ImageStore> else {
                self.logger.warning("Cannot get subimages of parent (id: \(parent)")
                throw AccessError.cannotGetSubimages
            }
            guard let subject = images.first(where: { $0.id! == id }) else {
                throw AccessError.cannotFindReferencedEntity
            }

            store.removeFromImages(subject)
            self.logger.info("Removed image (id: \(id) from subimages of parent: \(parent)")

            return subject
        }.flatMap { (store: ImageStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    self.logger.warning("Cannot find document (id: \(self.document)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                noteStore.addToImageTrash(store)
                self.logger.info("Moved image (id: \(id) to trash of document: \(self.document)")
            }
        }.eraseToAnyPublisher()
    }

    func restore(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<SubImageDescription, Error> {
        access.accessing(to: .read, id: id) { (imageStore: ImageStore?) in
            guard let imageStore = imageStore else {
                self.logger.warning("Cannot find image (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            return imageStore
        }.flatMap { (imageStore: ImageStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    self.logger.warning("Cannot parent document (id: \(self.document)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }

                noteStore.removeFromImageTrash(imageStore)
                self.logger.info("Removed image (id: \(id)) from trash of parent document (id: \(self.document))")

                return imageStore
            }
        }.flatMap { (imageStore: ImageStore) in
            self.access.accessing(to: .write, id: parent) { (parentLevel: NoteLevelStore?) in
                guard let parentLevel = parentLevel else {
                    self.logger.warning("Cannot parent level (id: \(parent)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                parentLevel.addToImages(imageStore)

                self.logger.info("Added image (id: \(id)) to subimages of parent (id: \(parent))")

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
            guard let levelStore = levelStore else {
                self.logger.warning("Cannot find level (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            return levelStore
        }.flatMap { (levelStore: NoteLevelStore) in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    self.logger.warning("Cannot parent document (id: \(self.document)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                noteStore.removeFromTrash(levelStore)
                self.logger.info("Removed level (id: \(id)) from trash of parent document (id: \(self.document))")
                return levelStore
            }
        }.flatMap { (levelStore: NoteLevelStore) in
            self.access.accessing(to: .write, id: parent) { (parentLevel: NoteLevelStore?) in
                guard let parentLevel = parentLevel else {
                    throw AccessError.cannotFindReferencedEntity
                }
                parentLevel.addToSublevels(levelStore)

                self.logger.info("Added level (id: \(id)) to sublevels of parent (id: \(parent))")

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
            guard let store = store else {
                self.logger.warning("Cannot find sublevel (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            self.logger.info("Read level (id: \(id) from db")
            return try NoteLevelDescription.from(store: store)
        }.eraseToAnyPublisher()
    }

    func read(image id: NoteImageID) -> AnyPublisher<NoteImageDescription?, Error> {
        access.accessing(to: .read, id: id) { (store: ImageStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find image (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }

            guard let preview = UIImage(data: store.preview!) else {
                self.logger.warning("Cannot create preview image")
                return nil
            }

            guard let image = UIImage(data: store.image!) else {
                self.logger.warning("Cannot create image")
                return nil
            }

            guard let drawing = try? PKDrawing(data: store.drawingAnnotation!) else {
                self.logger.warning("Cannot create drawing")
                return nil
            }

            self.logger.info("Read image (id: \(id) from db")

            return NoteImageDescription(id: ID(store.id!),
                                        preview: preview,
                                        drawing: drawing,
                                        image: image,
                                        frame: CGRect.from(store.frame!))
        }
    }

    func update(drawing: PKDrawing, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find level (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            store.drawing = drawing.dataRepresentation()

            self.logger.info("Updated annotation of level (id: \(id)")
        }
    }

    func update(annotation: PKDrawing, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find level (id: \(image)) in db")
                throw AccessError.cannotFindReferencedEntity
            }

            store.drawingAnnotation = annotation.dataRepresentation()

            self.logger.info("Updated annotation of image (id: \(image)")
        }
    }

    func update(preview: UIImage, for id: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: id) { (store: NoteLevelStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find image (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }

            store.preview = preview.pngData()!

            self.logger.info("Updated preview of image (id: \(id)")
        }
    }

    func update(preview: UIImage, image: NoteImageID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .write, id: image) { (store: ImageStore?) in
            guard let store = store else {
                self.logger.warning("Cannot find level (id: \(image)) in db")
                throw AccessError.cannotFindReferencedEntity
            }

            store.preview = preview.pngData()!

            self.logger.info("Updated preview of level (id: \(image)")
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
            guard let noteStore = noteStore else {
                self.logger.warning("Cannot find document (id: \(self.document) in db")
                throw AccessError.cannotFindReferencedEntity
            }

            guard let imageTrash = noteStore.imageTrash as? Set<ImageStore> else {
                self.logger.warning("Cannot get image trash of document (id: \(self.document)")
                throw AccessError.cannotGetImageTrash
            }

            imageTrash.forEach { self.access.delete($0) }
            noteStore.imageTrash = NSSet()

            guard let trash = noteStore.trash as? Set<NoteLevelStore> else {
                self.logger.warning("Cannot get level trash of document (id: \(self.document)")
                throw AccessError.cannotGetLevelTrash
            }
            trash.forEach { self.access.delete($0) }

            noteStore.trash = NSSet()

            self.logger.info("Emptied trash of document (id: \(self.document)")
        }
    }

    func moveToDrawer(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .read, id: id) { (imageStore: ImageStore?) -> ImageStore in
            guard let imageStore = imageStore else {
                self.logger.warning("Cannot find image (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }
            return imageStore
        }.flatMap { (imageStore: ImageStore) -> AnyPublisher<ImageStore, Error> in
            self.access.accessing(to: .write, id: parent) { (noteStore: NoteLevelStore?) in
                guard let note = noteStore else {
                    self.logger.warning("Cannot find note (id: \(parent)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                note.removeFromImages(imageStore)

                self.logger.info("Removed image (id: \(id)) from subimages of parent: \(parent)")

                return imageStore
            }
        }.flatMap { (imageStore: ImageStore) -> AnyPublisher<Void, Error> in
            self.access.accessing(to: .write, id: self.document) { (noteStore: NoteStore?) in
                guard let noteStore = noteStore else {
                    self.logger.warning("Cannot find document (id: \(self.document)) in db")
                    throw AccessError.cannotFindReferencedEntity
                }
                noteStore.addToImageDrawer(imageStore)

                self.logger.info("Added image (id: \(id)) to image drawer of document: \(self.document)")
            }
        }.eraseToAnyPublisher()
    }

    func moveToDrawer(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error> {
        access.accessing(to: .read, id: id) { (levelStore: NoteLevelStore?) -> NoteLevelStore in
            guard let levelStore = levelStore else {
                self.logger.warning("Cannot find level (id: \(id)) in db")
                throw AccessError.cannotFindReferencedEntity
            }
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
