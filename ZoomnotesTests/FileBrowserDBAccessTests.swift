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

    func testCreateFile() {
        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Root",
                                             documentChildren: [],
                                             directoryChildren: [])

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: root)

        let fileToBeCreated =
            DocumentStoreDescription(data: "Dummy",
                                     id: UUID(),
                                     lastModified: Date(),
                                     name: "New file",
                                     thumbnail: .checkmark)

        asynchronously(access: .write, moc: self.moc) {
            try access.directory.append(document: fileToBeCreated, to: root.id)
        }

        let result = asynchronously(access: .read, moc: self.moc) {
            return try access.file.read(id: fileToBeCreated.id)
        }

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.name, fileToBeCreated.name)
        XCTAssertEqual(result!.lastModified, fileToBeCreated.lastModified)

    }

    func testUpdateFileLastModified() {
        let fileToBeUpdated = DocumentStoreDescription.stub(data: String.empty)
        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [
                DocumentStoreDescription.stub(data: String.empty),
                fileToBeUpdated,
                DocumentStoreDescription.stub(data: String.empty)
                ],
                                                       directories: []))

        let newDate = Date().advanced(by: 24*68*60)
        asynchronously(access: .write, moc: self.moc) {
            try access.file.updateLastModified(of: fileToBeUpdated.id, with: newDate)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.file.read(id: fileToBeUpdated.id)
        }
        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.lastModified, newDate)
    }

    func testUpdateFileName() {
        let fileToBeUpdated = DocumentStoreDescription.stub(data: String.empty)
        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [
                DocumentStoreDescription.stub(data: String.empty),
                fileToBeUpdated,
                DocumentStoreDescription.stub(data: String.empty)
                ],
                                                       directories: []))

        let newName = "This name is surely better than the prevoius one"
        asynchronously(access: .write, moc: self.moc) {
            try access.file.updateName(of: fileToBeUpdated.id, to: newName)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.file.read(id: fileToBeUpdated.id)
        }

        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.name, newName)
    }

    func testUpdateDirectoryName() {
        let directoryToBeUpdated = DirectoryStoreDescription.stub
        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [],
                                                       directories: [
                                                        DirectoryStoreDescription.stub,
                                                        directoryToBeUpdated,
                                                        DirectoryStoreDescription.stub
            ]))

        let newName = "This name is surely better than the previous one"

        asynchronously(access: .write, moc: self.moc) {
            return try access.directory.updateName(id: directoryToBeUpdated.id, to: newName)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.directory.read(id: directoryToBeUpdated.id)
        }

        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.name, newName)
    }

    func testReparentDocument() {
        let destinationDirectory = DirectoryStoreDescription.stub
        let noteToBeMoved = DocumentStoreDescription.stub(data: "")

        let parentDirectory = DirectoryStoreDescription.stub(documents: [ noteToBeMoved ],
                                                             directories: [ destinationDirectory ])

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: parentDirectory)

        asynchronously(access: .write, moc: self.moc) {
            try access.directory.reparent(from: parentDirectory.id,
                                          node: .document(noteToBeMoved.id),
                                          to: destinationDirectory.id)
        }

        asynchronously(access: .read, moc: self.moc) {
            let children = try access.directory.children(of: parentDirectory.id)

            XCTAssertEqual(children.count, 1)
        }

        asynchronously(access: .read, moc: self.moc) {
            let children = try access.directory.children(of: destinationDirectory.id)

            XCTAssertEqual(children.count, 1)

            XCTAssertEqual(children.first!.id, noteToBeMoved.id)
        }

    }

    func testCreateDirectory() {
        let access = DirectoryAccessImpl(using: self.moc)
        let dirToBeCreated = DirectoryStoreDescription.stub
        asynchronously(access: .write, moc: self.moc) { return try access.create(from: dirToBeCreated) }

        let result = asynchronously(access: .read, moc: self.moc) { return try access.read(id: dirToBeCreated.id) }

        XCTAssertNotNil(result)

        XCTAssertEqual(result!.id, dirToBeCreated.id)
        XCTAssertEqual(result!.name, dirToBeCreated.name)
        XCTAssertEqual(result!.created, dirToBeCreated.created)
    }

    func testDeleteFile() {
        let fileToBeDeleted = DocumentStoreDescription.stub(data: String.empty)
        let unAffectedFile1 = DocumentStoreDescription.stub(data: String.empty)
        let unAffectedFile2 = DocumentStoreDescription.stub(data: String.empty)

        let parent = DirectoryStoreDescription.stub(documents: [
            fileToBeDeleted,
            unAffectedFile1,
            unAffectedFile2
            ],
                                                   directories: [])

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: parent)

        asynchronously(access: .write, moc: self.moc) {
            try access.directory.delete(child: .document(fileToBeDeleted.id), of: parent.id)
        }

        let filePlaceholder = asynchronously(access: .read, moc: self.moc) {
            return try access.file.read(id: fileToBeDeleted.id)
        }

        XCTAssertNil(filePlaceholder)

        let children = asynchronously(access: .read, moc: self.moc) {
            return try access.directory.children(of: parent.id)
        }

        XCTAssertEqual(children.count, 2)

        let (u1, u2) = asynchronously(access: .read, moc: self.moc) {
            return (try access.file.read(id: unAffectedFile1.id),
                    try access.file.read(id: unAffectedFile2.id))
        }

        XCTAssertNotNil(u1)
        XCTAssertEqual(u1!.id, unAffectedFile1.id)

        XCTAssertNotNil(u2)
        XCTAssertEqual(u2!.id, unAffectedFile2.id)
    }

    func testDeleteDirectory() {
        let directoryToBeDeleted =
            DirectoryStoreDescription.stub(documents: [ DocumentStoreDescription.stub(data: String.empty) ],
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

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: parent)

        asynchronously(access: .write, moc: self.moc) {
            try access.directory.delete(child: .directory(directoryToBeDeleted.id), of: parent.id)
        }

        let directoryPlaceholder = asynchronously(access: .read, moc: self.moc) {
            return try access.directory.read(id: directoryToBeDeleted.id)
        }

        XCTAssertNil(directoryPlaceholder)

        asynchronously(access: .read, moc: self.moc) {
            let children = try access.directory.children(of: parent.id)
            XCTAssertEqual(children.count, 2)
        }

        let (u1, u2) = asynchronously(access: .read, moc: self.moc) {
            return (try access.directory.read(id: unAffectedDirectory1.id),
                    try access.directory.read(id: unaffectedDirectory2.id))
        }

        XCTAssertNotNil(u1)
        XCTAssertEqual(u1!.id, unAffectedDirectory1.id)

        XCTAssertNotNil(u2)
        XCTAssertEqual(u2!.id, unaffectedDirectory2.id)

        let (doc1, dir1, dir2) = asynchronously(access: .read, moc: self.moc) {
            return (try access.file.read(id: directoryToBeDeleted.documentChildren[0].id),
                    try access.directory.read(id: directoryToBeDeleted.directoryChildren[0].id),
                    try access.directory.read(id: directoryToBeDeleted.directoryChildren[1].id))
        }

        XCTAssertNil(doc1)
        XCTAssertNil(dir1)
        XCTAssertNil(dir2)
    }

    func testMoveDirectory() {
        let newParent = DirectoryStoreDescription.stub
        let child = DirectoryStoreDescription.stub
        let parent = DirectoryStoreDescription.stub(documents: [ ],
                                                    directories: [ newParent, child ])

        let access =
            CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                           file: DocumentAccessImpl(using: self.moc))
                .stub(root: parent)

        asynchronously(access: .write, moc: self.moc) {
            try access.directory.reparent(from: parent.id,
                                          node: .directory(child.id),
                                          to: newParent.id)
        }

        let children = asynchronously(access: .read, moc: self.moc) {
            return try access.directory.children(of: newParent.id)
        }

        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children[0].id, child.id)

        let childrenOfOldParent = asynchronously(access: .read, moc: self.moc) {
            return try access.directory.children(of: parent.id)
        }

        XCTAssertEqual(childrenOfOldParent.count, 1)
    }
}
