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

    enum AccessType {
        case read
        case write
    }

    func asynchronously<T>(access: AccessType, _ action: () throws -> T) -> T {
        let expectation: XCTestExpectation

        switch access {
        case .read:
            expectation = self.expectation(description: "Do it!")
        case .write:
            expectation = self.expectation(forNotification: .NSManagedObjectContextDidSave, object: self.moc) { _ in return true }
        }

        do {
            let result = try action()
            if access == .read {
                expectation.fulfill()
            }
            self.waitForExpectations(timeout: 2.0) { error in XCTAssertNil(error)}
            return result
        } catch let error {
            XCTFail(error.localizedDescription)
            fatalError(error.localizedDescription)
        }
    }

    func testNoteLevelCreation() {
        let access = NoteLevelAccess(using: self.moc)
        let description = NoteLevelDescription(parent: UUID(),
                                               id: UUID(),
                                               preview: CodableImage(wrapping: .checkmark),
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               drawing: PKDrawing())

        asynchronously(access: .write) { try access.create(from: description) }

        let descriptionFromDB = asynchronously(access: .read) { try access.read(level: description.id) }
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

        asynchronously(access: .write) { try access.create(from: description) }

        asynchronously(access: .read) { try access.delete(level: description.id) }

        let descriptionPlaceholder = asynchronously(access: .read) { try access.read(level: description.id) }
        XCTAssertNil(descriptionPlaceholder)
    }

    func testUpdateDrawing() {
        let access = NoteLevelAccess(using: self.moc)
        let description = NoteLevelDescription(parent: UUID(),
                                               id: UUID(),
                                               preview: CodableImage(wrapping: .checkmark),
                                               frame: CGRect(x: 0, y: 0, width: 100, height: 200),
                                               drawing: PKDrawing())

        asynchronously(access: .write) { try access.create(from: description) }

        let newDrawing = PKDrawing()
        asynchronously(access: .write) { try access.update(drawing: newDrawing, for: description.id) }

        let descriptionFromDB = asynchronously(access: .read) { try access.read(level: description.id) }
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

        asynchronously(access: .write) { try access.create(from: description) }

        let newFrame = CGRect(x: 10, y: 10, width: 200, height: 300)
        asynchronously(access: .write) { try access.update(frame: newFrame, for: description.id) }

        let descriptionFromDB = asynchronously(access: .read) { try access.read(level: description.id) }
        XCTAssertNotNil(descriptionFromDB)
        XCTAssertEqual(descriptionFromDB!.parent, description.parent)
        XCTAssertEqual(descriptionFromDB!.id, description.id)
        XCTAssertEqual(descriptionFromDB!.frame, newFrame)
        XCTAssertEqual(descriptionFromDB!.drawing, description.drawing)
    }
}
