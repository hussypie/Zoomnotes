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

    func testNoteLevelCreation() {
        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [])

        let access = NoteLevelAccessImpl(using: self.moc).stub(with: rootLevel)

        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: UUID(),
                                               drawing: PKDrawing(),
                                               sublevels: [])

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

    func testNoteLevelDeletion() {
        let description = NoteLevelDescription(preview: .checkmark,
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               id: UUID(),
                                               drawing: PKDrawing(),
                                               sublevels: [])

        let rootLevel = NoteLevelDescription(preview: .checkmark,
                                             frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                             id: UUID(),
                                             drawing: PKDrawing(),
                                             sublevels: [description])

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
                                             sublevels: [])

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
                                             sublevels: [])

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
