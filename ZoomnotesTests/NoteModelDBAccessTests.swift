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
                                                root: rootLevel)

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access
                    .append(level: description, to: rootLevel.id)
                    .flatMap { access.read(level: description.id) }
                    .flatMap { descriptionFromDB -> AnyPublisher<NoteLevelDescription?, Error> in
                        XCTAssertNotNil(descriptionFromDB)
                        XCTAssertEqual(descriptionFromDB!.id, description.id)
                        XCTAssertEqual(descriptionFromDB!.frame, description.frame)
                        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)

                        return access.read(level: rootLevel.id)
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
                                                       root: rootLevel)

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access.remove(image: image.id, from: rootLevel.id)
                .flatMap { access.read(level: rootLevel.id) }
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
                                                root: rootLevel)

        _ = NoteLevelAccessImpl.stubP(using: DBAccess(moc: moc), with: document)
            .flatMap { access in
                access.remove(level: description.id, from: rootLevel.id)
                    .flatMap { access.read(level: description.id) }
                    .flatMap { descriptionPlaceholder -> AnyPublisher<NoteLevelDescription?, Error> in
                        XCTAssertNil(descriptionPlaceholder)
                        return access.read(level: rootLevel.id)
                }
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
}
