//
//  NoteModelDBAccessTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 19..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData
import PencilKit
import Combine
@testable import Zoomnotes

// swiftlint:disable type_body_length
class NoteModelDBAccessTests: XCTestCase {
    let moc: NSManagedObjectContext = NSPersistentContainer.inMemory(name: "Zoomnotes").viewContext

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    func testNoteLevelCreation() {
        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let access = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: access, with: document)
            .flatMap { levelDB in
                return levelDB
                    .append(level: description, to: rootLevel.id)
                    .flatMap { levelDB.read(level: description.id) }
                    .flatMap { descriptionFromDB -> AnyPublisher<NoteLevelDescription?, Error> in
                        XCTAssertNotNil(descriptionFromDB)
                        XCTAssertEqual(descriptionFromDB!.id, description.id)
                        XCTAssertEqual(descriptionFromDB!.frame, description.frame)
                        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)

                        return levelDB.read(level: rootLevel.id)
                }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK")},
               receiveError: { error in XCTFail(error.localizedDescription)},
               receiveValue: { parentFromDB in
                XCTAssertNotNil(parentFromDB)
                XCTAssertEqual(parentFromDB!.id, rootLevel.id)
                XCTAssertEqual(parentFromDB!.frame, rootLevel.frame)
                XCTAssertEqual(parentFromDB!.drawing, rootLevel.drawing)
        })
    }

    func testCreateSubImage() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [description],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access.append(image: image, to: rootLevel.id)
                    .flatMap { access.read(image: image.id) }
        }
        .sink(receiveDone: { XCTAssertTrue(true, "OK") },
              receiveError: { XCTFail($0.localizedDescription) },
              receiveValue: { imageFromDB in
                XCTAssertNotNil(imageFromDB)
                XCTAssertEqual(imageFromDB!.id, image.id)
                XCTAssertEqual(imageFromDB!.frame, image.frame)
                XCTAssertEqual(imageFromDB!.drawing, image.drawing)
        })
    }

    func testRemoveSubImage() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access -> AnyPublisher<NoteLevelDescription?, Error> in
                access.remove(image: image.id, from: rootLevel.id)
                    .flatMap { access.read(level: rootLevel.id) }
                    .flatMap { (desc: NoteLevelDescription?) -> AnyPublisher<NoteLevelDescription?, Error> in
                        return DirectoryAccessImpl(access: dbaccess)
                            .noteModel(of: document.id)
                            .map { (docFromDB: DocumentLookupResult?) -> NoteLevelDescription? in
                                XCTAssertNotNil(docFromDB)
                                XCTAssert(docFromDB!.imageDrawer.isEmpty)
                                XCTAssert(docFromDB!.levelDrawer.isEmpty)
                                XCTAssert(docFromDB!.levelTrash.isEmpty)
                                XCTAssertEqual(docFromDB!.imageTrash.count, 1)

                                let imageInTrash = docFromDB!.imageTrash.first!
                                XCTAssertEqual(imageInTrash.id, image.id)
                                XCTAssertEqual(imageInTrash.frame, image.frame)

                                return desc
                        }.eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB)
                XCTAssert(rootFromDB!.images.isEmpty)
        })
    }

    func testUpdateSubImageAnnotation() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let newAnnotation = PKDrawing()

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access.update(annotation: newAnnotation, image: image.id)
                    .flatMap { access.read(level: rootLevel.id) }

        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB!.images.first)
                XCTAssertEqual(rootFromDB!.images.first!.drawing, newAnnotation)
        })
    }

    func testMoveSubImage() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let newFrame = CGRect(x: 100, y: 100, width: 1000, height: 1000)

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access.update(frame: newFrame, image: image.id)
                    .flatMap { access.read(level: rootLevel.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB!.images.first)
                XCTAssertEqual(rootFromDB!.images.first!.frame, newFrame)
        })

    }

    func testNoteLevelDeletion() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [description],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)
        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access in
                access.remove(level: description.id, from: rootLevel.id)
                    .flatMap { access.read(level: rootLevel.id) }
                    .flatMap { (desc: NoteLevelDescription?) -> AnyPublisher<NoteLevelDescription?, Error> in
                        return DirectoryAccessImpl(access: dbaccess)
                            .noteModel(of: document.id)
                            .map { (docFromDB: DocumentLookupResult?) -> NoteLevelDescription? in
                                XCTAssertNotNil(docFromDB)
                                XCTAssert(docFromDB!.imageDrawer.isEmpty)
                                XCTAssert(docFromDB!.levelDrawer.isEmpty)
                                XCTAssert(docFromDB!.imageTrash.isEmpty)
                                XCTAssertEqual(docFromDB!.levelTrash.count, 1)

                                let levelInTrash = docFromDB!.levelTrash.first!
                                XCTAssertEqual(levelInTrash.id, description.id)
                                XCTAssertEqual(levelInTrash.frame, description.frame)

                                return desc
                        }.eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { parentFromDb in
                XCTAssertNotNil(parentFromDb)
                XCTAssert(parentFromDb!.sublevels.isEmpty)
        })
    }

    func testUpdateDrawing() {
        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let newDrawing = PKDrawing()

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access.update(drawing: newDrawing, for: rootLevel.id)
                    .flatMap { access.read(level: rootLevel.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { descriptionFromDB in
                XCTAssertNotNil(descriptionFromDB)
                XCTAssertEqual(descriptionFromDB!.id, rootLevel.id)
                XCTAssertEqual(descriptionFromDB!.frame, rootLevel.frame)
                XCTAssertEqual(descriptionFromDB!.drawing, newDrawing)
        })
    }

    func testUpdateFrame() {
        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let newFrame = CGRect(x: 10, y: 10, width: 200, height: 300)

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access  in
                access.update(frame: newFrame, for: rootLevel.id)
                    .flatMap { access.read(level: rootLevel.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { descriptionFromDB in
                XCTAssertNotNil(descriptionFromDB)
                XCTAssertEqual(descriptionFromDB!.id, rootLevel.id)
                XCTAssertEqual(descriptionFromDB!.frame, newFrame)
                XCTAssertEqual(descriptionFromDB!.drawing, rootLevel.drawing)
        })
    }

    func testRestoreSubLevelAfterDelete() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [ description ],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access -> AnyPublisher<NoteLevelDescription?, Error> in
                access.restore(level: description.id, to: rootLevel.id)
                    .map { sublevel in
                        XCTAssertEqual(sublevel.id, description.id)
                        XCTAssertEqual(sublevel.frame, description.frame)
                }
                .flatMap { _ -> AnyPublisher<Void, Error> in
                    return DirectoryAccessImpl(access: dbaccess)
                        .noteModel(of: document.id)
                        .map { (docFromDB: DocumentLookupResult?) -> Void in
                            XCTAssertNotNil(docFromDB)
                            XCTAssert(docFromDB!.imageDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelTrash.isEmpty)
                            XCTAssert(docFromDB!.imageTrash.isEmpty)
                    }.eraseToAnyPublisher()
                }.flatMap { access.read(level: rootLevel.id) }
                    .eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB)
                XCTAssert(rootFromDB!.images.isEmpty)
                XCTAssertEqual(rootFromDB!.sublevels.count, 1)

                let sublevel = rootFromDB!.sublevels.first!

                XCTAssertEqual(sublevel.id, description.id)
                XCTAssertEqual(sublevel.frame, description.frame)
        })
    }

    func testRestoreSubImageAfterDelete() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [ image ],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access -> AnyPublisher<NoteLevelDescription?, Error> in
                access.restore(image: image.id, to: rootLevel.id)
                    .map { subimage in
                        XCTAssertEqual(subimage.id, image.id)
                        XCTAssertEqual(subimage.frame, image.frame)
                }
                .flatMap { _ -> AnyPublisher<Void, Error> in
                    return DirectoryAccessImpl(access: dbaccess)
                        .noteModel(of: document.id)
                        .map { (docFromDB: DocumentLookupResult?) -> Void in
                            XCTAssertNotNil(docFromDB)
                            XCTAssert(docFromDB!.imageDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelTrash.isEmpty)
                            XCTAssert(docFromDB!.imageTrash.isEmpty)
                    }.eraseToAnyPublisher()
                }.flatMap { access.read(level: rootLevel.id) }
                    .eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB)
                XCTAssert(rootFromDB!.sublevels.isEmpty)
                XCTAssertEqual(rootFromDB!.images.count, 1)

                let subimage = rootFromDB!.images.first!

                XCTAssertEqual(subimage.id, image.id)
                XCTAssertEqual(subimage.frame, image.frame)
        })
    }

    func testEmptyTrash() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [ image ],
                                                levelTrash: [ description ],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access in access.emptyTrash() }
            .flatMap { _ -> AnyPublisher<DocumentLookupResult?, Error> in
                return DirectoryAccessImpl(access: dbaccess)
                    .noteModel(of: document.id)
        }.sink(receiveDone: { XCTAssert(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { (docFromDB: DocumentLookupResult?) in
                XCTAssertNotNil(docFromDB)
                XCTAssert(docFromDB!.imageDrawer.isEmpty)
                XCTAssert(docFromDB!.levelDrawer.isEmpty)
                XCTAssert(docFromDB!.levelTrash.isEmpty)
                XCTAssert(docFromDB!.imageTrash.isEmpty)
                XCTAssert(docFromDB!.root.images.isEmpty)
                XCTAssert(docFromDB!.root.sublevels.isEmpty)
        })
    }

    func testMoveSublevelToDrawer() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [description],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)
        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access in
                access.moveToDrawer(level: description.id, from: rootLevel.id)
                    .flatMap { access.read(level: rootLevel.id) }
                    .flatMap { (desc: NoteLevelDescription?) -> AnyPublisher<NoteLevelDescription?, Error> in
                        return DirectoryAccessImpl(access: dbaccess)
                            .noteModel(of: document.id)
                            .map { (docFromDB: DocumentLookupResult?) -> NoteLevelDescription? in
                                XCTAssertNotNil(docFromDB)
                                XCTAssert(docFromDB!.imageDrawer.isEmpty)
                                XCTAssert(docFromDB!.imageTrash.isEmpty)
                                XCTAssert(docFromDB!.levelTrash.isEmpty)
                                XCTAssertEqual(docFromDB!.levelDrawer.count, 1)

                                let levelInDrawer = docFromDB!.levelDrawer.first!
                                XCTAssertEqual(levelInDrawer.id, description.id)
                                XCTAssertEqual(levelInDrawer.frame, description.frame)

                                return desc
                        }.eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { parentFromDb in
                XCTAssertNotNil(parentFromDb)
                XCTAssert(parentFromDb!.sublevels.isEmpty)
                XCTAssert(parentFromDb!.images.isEmpty)
        })
    }

    func testMoveSublevelFromDrawer() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: ID(UUID()),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [ description ],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access -> AnyPublisher<NoteLevelDescription?, Error> in
                access.moveFromDrawer(level: description.id, to: rootLevel.id)
                .flatMap { _ -> AnyPublisher<Void, Error> in
                    return DirectoryAccessImpl(access: dbaccess)
                        .noteModel(of: document.id)
                        .map { (docFromDB: DocumentLookupResult?) -> Void in
                            XCTAssertNotNil(docFromDB)
                            XCTAssert(docFromDB!.imageDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelTrash.isEmpty)
                            XCTAssert(docFromDB!.imageTrash.isEmpty)
                    }.eraseToAnyPublisher()
                }.flatMap { access.read(level: rootLevel.id) }
                    .eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB)
                XCTAssert(rootFromDB!.images.isEmpty)
                XCTAssertEqual(rootFromDB!.sublevels.count, 1)

                let sublevel = rootFromDB!.sublevels.first!

                XCTAssertEqual(sublevel.id, description.id)
                XCTAssertEqual(sublevel.frame, description.frame)
        })
    }

    func testMoveSubimageToDrawer() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access -> AnyPublisher<NoteLevelDescription?, Error> in
                access.moveToDrawer(image: image.id, from: rootLevel.id)
                    .flatMap { access.read(level: rootLevel.id) }
                    .flatMap { (desc: NoteLevelDescription?) -> AnyPublisher<NoteLevelDescription?, Error> in
                        return DirectoryAccessImpl(access: dbaccess)
                            .noteModel(of: document.id)
                            .map { (docFromDB: DocumentLookupResult?) -> NoteLevelDescription? in
                                XCTAssertNotNil(docFromDB)
                                XCTAssert(docFromDB!.imageTrash.isEmpty)
                                XCTAssert(docFromDB!.levelDrawer.isEmpty)
                                XCTAssert(docFromDB!.levelTrash.isEmpty)
                                XCTAssertEqual(docFromDB!.imageDrawer.count, 1)

                                let imageInTrash = docFromDB!.imageDrawer.first!
                                XCTAssertEqual(imageInTrash.id, image.id)
                                XCTAssertEqual(imageInTrash.frame, image.frame)

                                return desc
                        }.eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB)
                XCTAssert(rootFromDB!.sublevels.isEmpty)
                XCTAssert(rootFromDB!.images.isEmpty)
        })
    }

    func testMoveSubimageFromDrawer() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: ID(UUID()),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Example document",
                                                thumbnail: .checkmark,
                                                imageDrawer: [ image ],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let dbaccess = DBAccess(moc: moc)

        _ = NoteLevelAccessImpl.stubP(using: dbaccess, with: document)
            .flatMap { access -> AnyPublisher<NoteLevelDescription?, Error> in
                access.moveFromDrawer(image: image.id, to: rootLevel.id)
                .flatMap { _ -> AnyPublisher<Void, Error> in
                    return DirectoryAccessImpl(access: dbaccess)
                        .noteModel(of: document.id)
                        .map { (docFromDB: DocumentLookupResult?) -> Void in
                            XCTAssertNotNil(docFromDB)
                            XCTAssert(docFromDB!.imageDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelDrawer.isEmpty)
                            XCTAssert(docFromDB!.levelTrash.isEmpty)
                            XCTAssert(docFromDB!.imageTrash.isEmpty)
                    }.eraseToAnyPublisher()
                }.flatMap { access.read(level: rootLevel.id) }
                    .eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootFromDB in
                XCTAssertNotNil(rootFromDB)
                XCTAssert(rootFromDB!.sublevels.isEmpty)
                XCTAssertEqual(rootFromDB!.images.count, 1)

                let subimage = rootFromDB!.images.first!

                XCTAssertEqual(subimage.id, image.id)
                XCTAssertEqual(subimage.frame, image.frame)
        })
    }
}
