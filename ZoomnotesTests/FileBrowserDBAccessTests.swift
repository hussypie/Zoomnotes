//
//  FileBrowserDBAccessTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 14..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData

@testable import Zoomnotes

class FileBrowserDBAccessTests: XCTestCase {
    let moc = NSPersistentContainer.inMemory(name: "Zoomnotes").viewContext

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    enum AccessType {
        case read
        case write
    }

    func asynchronously<T>(access: AccessType,
                           moc: NSManagedObjectContext,
                           _ action: () throws -> T
    ) -> T {
        let expectation: XCTestExpectation

        switch access {
        case .read:
            expectation = self.expectation(description: "Do it!")
        case .write:
            expectation = self.expectation(forNotification: .NSManagedObjectContextDidSave, object: moc) { _ in return true }
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

    func testCreateFile() {
        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Root",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessImpl(using: self.moc).stub(root: root)

        let rootLevel = NoteLevelDescription.stub(parent: nil)
        let fileToBeCreated =
            DocumentStoreDescription(id: UUID(),
                                     lastModified: Date(),
                                     name: "New file",
                                     thumbnail: .checkmark,
                                     root: rootLevel)

        asynchronously(access: .write, moc: self.moc) {
            try access.append(document: fileToBeCreated, to: root.id)
        }

        let result = asynchronously(access: .read, moc: self.moc) {
            return try access.children(of: root.id)
        }

        XCTAssertEqual(result.count, 1)

        switch result.first! {
        case .file(let file):
            XCTAssertEqual(file.id, fileToBeCreated.id.id)
            XCTAssertEqual(file.name, fileToBeCreated.name)
            XCTAssertEqual(file.lastModified, fileToBeCreated.lastModified)
        default:
            XCTFail("Created file shoud be file")
        }

        let noteLevelAccess = NoteLevelAccessImpl(using: self.moc)

        let rootLevel2 = asynchronously(access: .read, moc: self.moc) {
            return try noteLevelAccess.read(level: rootLevel.id)
        }

        XCTAssertNotNil(rootLevel2)
        XCTAssertEqual(rootLevel2!.id, rootLevel.id)
    }

    func testUpdateFileLastModified() {
        let fileToBeUpdated = DocumentStoreDescription.stub
        let root = DirectoryStoreDescription.stub(documents: [
            DocumentStoreDescription.stub,
            fileToBeUpdated,
            DocumentStoreDescription.stub
        ], directories: [])

        let access = DirectoryAccessImpl(using: self.moc).stub(root: root)

        let newDate = Date().advanced(by: 24*68*60)
        asynchronously(access: .write, moc: self.moc) {
            try access.updateLastModified(of: fileToBeUpdated.id, with: newDate)
        }

        let children = asynchronously(access: .read, moc: self.moc) {
            return try access.children(of: root.id)
        }

        XCTAssertEqual(children.count, 3)
        let updatedFile = children.first { $0.id == fileToBeUpdated.id.id }!
        XCTAssertEqual(updatedFile.date, newDate)
    }

    func testUpdateFileName() {
        let fileToBeUpdated = DocumentStoreDescription.stub
       let root = DirectoryStoreDescription.stub(documents: [
            DocumentStoreDescription.stub,
            fileToBeUpdated,
            DocumentStoreDescription.stub
        ], directories: [])

        let access = DirectoryAccessImpl(using: self.moc).stub(root: root)

        let newName = "This name is surely better than the prevoius one"
        asynchronously(access: .write, moc: self.moc) {
            try access.updateName(of: fileToBeUpdated.id, to: newName)
        }

        let children = asynchronously(access: .read, moc: self.moc) {
            return try access.children(of: root.id)
        }

        XCTAssertEqual(children.count, 3)
        let updatedFile = children.first { $0.id == fileToBeUpdated.id.id }!
        XCTAssertEqual(updatedFile.name, newName)
    }

    func testUpdateDirectoryName() {
        let directoryToBeUpdated = DirectoryStoreDescription.stub
        let access = DirectoryAccessImpl(using: self.moc)
            .stub(root: DirectoryStoreDescription.stub(documents: [],
                                                       directories: [
                                                        DirectoryStoreDescription.stub,
                                                        directoryToBeUpdated,
                                                        DirectoryStoreDescription.stub
            ]))

        let newName = "This name is surely better than the previous one"

        asynchronously(access: .write, moc: self.moc) {
            return try access.updateName(of: directoryToBeUpdated.id, to: newName)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: directoryToBeUpdated.id)
        }

        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.name, newName)
    }

    func testReparentDocument() {
        let destinationDirectory = DirectoryStoreDescription.stub
        let noteToBeMoved = DocumentStoreDescription.stub

        let parentDirectory = DirectoryStoreDescription.stub(documents: [ noteToBeMoved ],
                                                             directories: [ destinationDirectory ])

        let access = DirectoryAccessImpl(using: self.moc)
            .stub(root: parentDirectory)

        asynchronously(access: .write, moc: self.moc) {
            try access.reparent(from: parentDirectory.id,
                                node: noteToBeMoved.id,
                                to: destinationDirectory.id)
        }

        asynchronously(access: .read, moc: self.moc) {
            let children = try access.children(of: parentDirectory.id)

            XCTAssertEqual(children.count, 1)
        }

        asynchronously(access: .read, moc: self.moc) {
            let children = try access.children(of: destinationDirectory.id)

            XCTAssertEqual(children.count, 1)

            XCTAssertEqual(children.first!.id, noteToBeMoved.id.id)
        }

    }

    func testCreateDirectory() {
        let access = DirectoryAccessImpl(using: self.moc)
        let dirToBeCreated = DirectoryStoreDescription.stub
        asynchronously(access: .write, moc: self.moc) { return try access.root(from: dirToBeCreated) }

        let result = asynchronously(access: .read, moc: self.moc) { return try access.read(id: dirToBeCreated.id) }

        XCTAssertNotNil(result)

        XCTAssertEqual(result!.id, dirToBeCreated.id)
        XCTAssertEqual(result!.name, dirToBeCreated.name)
        XCTAssertEqual(result!.created, dirToBeCreated.created)
    }

    func testDeleteFile() {
        let fileToBeDeleted = DocumentStoreDescription.stub
        let unAffectedFile1 = DocumentStoreDescription.stub
        let unAffectedFile2 = DocumentStoreDescription.stub

        let parent = DirectoryStoreDescription.stub(documents: [
            fileToBeDeleted,
            unAffectedFile1,
            unAffectedFile2
            ],
                                                    directories: [])

        let access = DirectoryAccessImpl(using: self.moc)
            .stub(root: parent)

        asynchronously(access: .write, moc: self.moc) {
            try access.delete(child: fileToBeDeleted.id, of: parent.id)
        }

        let children = asynchronously(access: .read, moc: self.moc) {
            return try access.children(of: parent.id)
        }

        XCTAssertEqual(children.count, 2)
        XCTAssertNil(children.first { $0.id == fileToBeDeleted.id.id })

        XCTAssertNotNil(children.first { $0.id == unAffectedFile1.id.id })

        XCTAssertNotNil(children.first { $0.id == unAffectedFile2.id.id })
    }

    func testDeleteDirectory() {
        let directoryToBeDeleted =
            DirectoryStoreDescription.stub(documents: [ DocumentStoreDescription.stub ],
                                           directories: [
                                            DirectoryStoreDescription.stub,
                                            DirectoryStoreDescription.stub
            ])
        let unAffectedDirectory1 = DirectoryStoreDescription.stub
        let unaffectedDirectory2 = DirectoryStoreDescription.stub

        let parent = DirectoryStoreDescription.stub(documents: [],
                                                    directories: [
                                                        directoryToBeDeleted,
                                                        unAffectedDirectory1,
                                                        unaffectedDirectory2
        ])

        let access = DirectoryAccessImpl(using: self.moc)
            .stub(root: parent)

        asynchronously(access: .write, moc: self.moc) {
            try access.delete(child: directoryToBeDeleted.id, of: parent.id)
        }

        let directoryPlaceholder = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: directoryToBeDeleted.id)
        }

        XCTAssertNil(directoryPlaceholder)

        asynchronously(access: .read, moc: self.moc) {
            let children = try access.children(of: parent.id)
            XCTAssertEqual(children.count, 2)
        }

        let (u1, u2) = asynchronously(access: .read, moc: self.moc) {
            return (try access.read(id: unAffectedDirectory1.id),
                    try access.read(id: unaffectedDirectory2.id))
        }

        XCTAssertNotNil(u1)
        XCTAssertEqual(u1!.id, unAffectedDirectory1.id)

        XCTAssertNotNil(u2)
        XCTAssertEqual(u2!.id, unaffectedDirectory2.id)
    }

    func testMoveDirectory() {
        let newParent = DirectoryStoreDescription.stub
        let child = DirectoryStoreDescription.stub
        let parent = DirectoryStoreDescription.stub(documents: [ ],
                                                    directories: [ newParent, child ])

        let access = DirectoryAccessImpl(using: self.moc).stub(root: parent)

        asynchronously(access: .write, moc: self.moc) {
            try access.reparent(from: parent.id,
                                node: child.id,
                                to: newParent.id)
        }

        let children = asynchronously(access: .read, moc: self.moc) {
            return try access.children(of: newParent.id)
        }

        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children[0].id, child.id.id)

        let childrenOfOldParent = asynchronously(access: .read, moc: self.moc) {
            return try access.children(of: parent.id)
        }

        XCTAssertEqual(childrenOfOldParent.count, 1)
    }
}
