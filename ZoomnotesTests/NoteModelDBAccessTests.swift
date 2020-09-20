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
        let access = NoteLevelAccess(using: self.moc)
        let description = NoteLevelDescription(parent: UUID(),
                                               id: UUID(),
                                               preview: CodableImage(wrapping: .checkmark),
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               drawing: PKDrawing())

        asynchronously(access: .write, moc: self.moc) { try access.create(from: description) }

        let descriptionFromDB = asynchronously(access: .read, moc: self.moc) { try access.read(level: description.id) }
        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.parent, description.parent)
        XCTAssertEqual(descriptionFromDB!.id, description.id)
        XCTAssertEqual(descriptionFromDB!.frame, description.frame)
        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)
    }

    func testNoteLevelDeletion() {
        let access = NoteLevelAccess(using: self.moc)
        let description = NoteLevelDescription(parent: UUID(),
                                               id: UUID(),
                                               preview: CodableImage(wrapping: .checkmark),
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               drawing: PKDrawing())

        asynchronously(access: .write, moc: self.moc) { try access.create(from: description) }

        asynchronously(access: .read, moc: self.moc) { try access.delete(level: description.id) }

        let descriptionPlaceholder = asynchronously(access: .read, moc: self.moc) { try access.read(level: description.id) }
        XCTAssertNil(descriptionPlaceholder)
    }

    func testUpdateDrawing() {
        let access = NoteLevelAccess(using: self.moc)
        let description = NoteLevelDescription(parent: UUID(),
                                               id: UUID(),
                                               preview: CodableImage(wrapping: .checkmark),
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               drawing: PKDrawing())

        asynchronously(access: .write, moc: self.moc) { try access.create(from: description) }

        let newDrawing = PKDrawing()
        asynchronously(access: .write, moc: self.moc) { try access.update(drawing: newDrawing, for: description.id) }

        let descriptionFromDB = asynchronously(access: .read, moc: self.moc) { try access.read(level: description.id) }
        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.parent, description.parent)
        XCTAssertEqual(descriptionFromDB!.id, description.id)
        XCTAssertEqual(descriptionFromDB!.frame, description.frame)
        XCTAssertEqual(descriptionFromDB!.drawing, newDrawing)
    }

    func testUpdateFrame() {
        let access = NoteLevelAccess(using: self.moc)
        let description = NoteLevelDescription(parent: UUID(),
                                               id: UUID(),
                                               preview: CodableImage(wrapping: .checkmark),
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               drawing: PKDrawing())

        asynchronously(access: .write, moc: self.moc) { try access.create(from: description) }

        let newFrame = CGRect(x: 10, y: 10, width: 200, height: 300)
        asynchronously(access: .write, moc: self.moc) { try access.update(frame: newFrame, for: description.id) }

        let descriptionFromDB = asynchronously(access: .read, moc: self.moc) { try access.read(level: description.id) }
        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.parent, description.parent)
        XCTAssertEqual(descriptionFromDB!.id, description.id)
        XCTAssertEqual(descriptionFromDB!.frame, newFrame)
        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)
    }
}
