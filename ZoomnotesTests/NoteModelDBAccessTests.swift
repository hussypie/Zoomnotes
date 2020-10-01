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
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: UUID(),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        asynchronously(access: .write, moc: self.moc) {
            try access.append(level: description, to: rootLevel.id)
        }

        let descriptionFromDB = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: description.id)
        }

        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.id, description.id)
        XCTAssertEqual(descriptionFromDB!.frame, description.frame)
        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)

        let parentFromDb = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: rootLevel.id)
        }

        XCTAssertNotNil(parentFromDb)
        XCTAssertEqual(parentFromDb!.sublevels.count, 1)
        XCTAssertEqual(parentFromDb!.sublevels.first!.id, description.id)
    }

    func testCreateSubImage() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: UUID(),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [description],
                                             images: [])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        let image = NoteImageDescription(id: UUID(),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        asynchronously(access: .read, moc: self.moc) {
            try access.append(image: image, to: rootLevel.id)
        }

        let imageFromDB = asynchronously(access: .read, moc: self.moc) {
            return try access.read(level: rootLevel.id)
        }

        XCTAssertEqual(imageFromDB!.images.count, 1)
        XCTAssertEqual(imageFromDB!.images.first!.id, image.id)
        XCTAssertEqual(imageFromDB!.images.first!.frame, image.frame)
        XCTAssertEqual(imageFromDB!.images.first!.drawing, image.drawing)
    }

    func testRemoveSubImage() {
        let image = NoteImageDescription(id: UUID(),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        asynchronously(access: .write, moc: self.moc) {
            try access.remove(image: image.id, from: rootLevel.id)
        }

        let rootFromDB = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: rootLevel.id)
        }

        XCTAssert(rootFromDB!.images.isEmpty)
    }

    func testUpdateSubImageAnnotation() {
        let image = NoteImageDescription(id: UUID(),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        let newAnnotation = PKDrawing()
        asynchronously(access: .write, moc: self.moc) {
            try access.update(annotation: newAnnotation, image: image.id)
        }

        let rootFromDB = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: rootLevel.id)
        }

        XCTAssertNotNil(rootFromDB!.images.first)
        XCTAssertEqual(rootFromDB!.images.first!.drawing, newAnnotation)
    }

    func testMoveSubImage() {
        let image = NoteImageDescription(id: UUID(),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [image])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        let newFrame = CGRect(x: 100, y: 100, width: 1000, height: 1000)
        asynchronously(access: .write, moc: self.moc) {
            try access.update(frame: newFrame, image: image.id)
        }

        let rootFromDB = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: rootLevel.id)
        }

        XCTAssertNotNil(rootFromDB!.images.first)
        XCTAssertEqual(rootFromDB!.images.first!.frame, newFrame)
    }

    func testNoteLevelDeletion() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: UUID(),
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [description],
                                             images: [])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        asynchronously(access: .read, moc: self.moc) {
            try access.remove(level: description.id, from: rootLevel.id)
        }

        let descriptionPlaceholder = asynchronously(access: .read, moc: self.moc) { try access.read(level: description.id) }
        XCTAssertNil(descriptionPlaceholder)

        let parentFromDb = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: rootLevel.id)
        }

        XCTAssertNotNil(parentFromDb)
        XCTAssert(parentFromDb!.sublevels.isEmpty)
    }

    func testUpdateDrawing() {
        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        let newDrawing = PKDrawing()
        asynchronously(access: .write, moc: self.moc) {
            try access.update(drawing: newDrawing, for: rootLevel.id)
        }

        let descriptionFromDB = asynchronously(access: .read, moc: self.moc) {
            try access.read(level: rootLevel.id)
        }
        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.id, rootLevel.id)
        XCTAssertEqual(descriptionFromDB!.frame, rootLevel.frame)
        XCTAssertEqual(descriptionFromDB!.drawing, newDrawing)
    }

    func testUpdateFrame() {
        let description = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [],
                                             images: [])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: description)

        let newFrame = CGRect(x: 10, y: 10, width: 200, height: 300)
        asynchronously(access: .write, moc: self.moc) {
            try access.update(frame: newFrame, for: description.id)
        }

        let descriptionFromDB = asynchronously(access: .read, moc: self.moc) { try access.read(level: description.id) }
        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.id, description.id)
        XCTAssertEqual(descriptionFromDB!.frame, newFrame)
        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)
    }
}
