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

extension DocumentAccess.StoreDescription {
    private static let stubImages: [UIImage] = [.actions, .checkmark, .remove, .add]
    private static let stubNames: [String] = ["Cats", "Dogs", "Unit tests"]

    static func stub(data: String, parent: UUID) -> DocumentAccess.StoreDescription {
        return DocumentAccess.StoreDescription(data: data,
                                               id: UUID(),
                                               lastModified: Date(),
                                               name: stubNames.randomElement()!,
                                               parent: parent,
                                               thumbnail: stubImages.randomElement()!)
    }
}

extension DirectoryVM {
    private static let stubNames: [String] = ["Cats", "Dogs", "Unit tests"]

    static var stub: DirectoryVM {
        return DirectoryVM.fresh(name: stubNames.randomElement()!, created: Date())
    }
}

class FileBrowserDBAccessTests: XCTestCase {
    let moc = NSPersistentContainer.inMemory(name: "Zoomnotes").viewContext

    func testCreateFile() {
        self.continueAfterFailure = false

        let access = DocumentAccess(using: self.moc)
        let parentId = UUID()
        let fileToBeCreated =
            DocumentAccess.StoreDescription(data: "Dummy",
                                            id: UUID(),
                                            lastModified: Date(),
                                            name: "New file",
                                            parent: parentId,
                                            thumbnail: .checkmark)

        asynchronously(access: .write, moc: self.moc) {
            try access.create(from: fileToBeCreated)
        }

        let result = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: fileToBeCreated.id)
        }

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.name, fileToBeCreated.name)
        XCTAssertEqual(result!.lastModified, fileToBeCreated.lastModified)

    }

    func testUpdateFileLastModified() {
        self.continueAfterFailure = false

        let fileToBeUpdated = DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID())
        let access = DocumentAccess(using: self.moc)
            .stub(with: [
                DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID()),
                fileToBeUpdated,
                DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID())
            ])

        let newDate = Date().advanced(by: 24*68*60)
        asynchronously(access: .write, moc: self.moc) {
            try access.updateLastModified(of: fileToBeUpdated.id, with: newDate)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: fileToBeUpdated.id)
        }
        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.lastModified, newDate)
    }

    func testUpdateFileName() {
        self.continueAfterFailure = false

        let fileToBeUpdated = DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID())
        let access = DocumentAccess(using: self.moc)
            .stub(with: [
                DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID()),
                fileToBeUpdated,
                DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID())
            ])

        let newName = "This name is surely better than the prevoius one"
        asynchronously(access: .write, moc: self.moc) {
            try access.updateName(of: fileToBeUpdated.id, to: newName)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: fileToBeUpdated.id)
        }

        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.name, newName)
    }

    func testUpdateDirectoryName() {
        self.continueAfterFailure = false

        let directoryToBeUpdated = DirectoryVM.stub
        let access = DirectoryAccess(using: self.moc).stub(with: [ DirectoryVM.stub, directoryToBeUpdated, DirectoryVM.stub])
        let newName = "This name is surely better than the previous one"

        asynchronously(access: .write, moc: self.moc) {
            return try access.updateName(for: directoryToBeUpdated, to: newName)
        }

        let updatedFile = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: directoryToBeUpdated.id)
        }

        XCTAssertNotNil(updatedFile)
        XCTAssertEqual(updatedFile!.name, newName)
    }

    func testDeleteFile() {
        let fileToBeDeleted = DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID())
        let access = DocumentAccess(using: self.moc)
            .stub(with: [
                DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID()),
                fileToBeDeleted,
                DocumentAccess.StoreDescription.stub(data: String.empty, parent: UUID())
            ])

        asynchronously(access: .write, moc: self.moc) { try access.delete(fileToBeDeleted.id) }

        let filePlaceholder = asynchronously(access: .read, moc: self.moc) { return try access.read(id: fileToBeDeleted.id) }

        XCTAssertNil(filePlaceholder)
    }

    func testReparentDocument() {
        self.continueAfterFailure = false
        let access = CoreDataAccess(using: self.moc)
        let destinationDirectory = DirectoryVM.stub
        let parentDirectory = DirectoryVM.stub
        let noteToBeMoved = DocumentAccess.StoreDescription.stub(data: "", parent: parentDirectory.id)

        asynchronously(access: .write, moc: self.moc) {
            try access.directory.create(from: destinationDirectory, with: parentDirectory.id)
            try access.directory.create(from: parentDirectory, with: parentDirectory.id)
            try access.file.create(from: noteToBeMoved)
        }

        asynchronously(access: .write, moc: self.moc) {
            try access.file.reparent(from: parentDirectory.id,
                                     file: noteToBeMoved.id,
                                     to: destinationDirectory.id)
        }

        asynchronously(access: .read, moc: self.moc) {
            let folders = try access.directory.children(of: parentDirectory.id)
            let documentsInParent = try access.file.children(of: parentDirectory.id)

            XCTAssertEqual(folders.count, 1)
            XCTAssertEqual(documentsInParent.count, 0)
        }

        asynchronously(access: .read, moc: self.moc) {
            let foldersInDestination = try access.directory.children(of: destinationDirectory.id)
            let documentsInDestination = try access.file.children(of: destinationDirectory.id)

            XCTAssertEqual(foldersInDestination.count, 0)
            XCTAssertEqual(documentsInDestination.count, 1)

            XCTAssertEqual(documentsInDestination.first!.id, noteToBeMoved.id)
        }

    }

    func testCreateDirectory() {
        self.continueAfterFailure = false

        let access = DirectoryAccess(using: self.moc)
        let parentId = UUID()
        let dirToBeCreated = DirectoryVM.fresh(name: "New folder", created: Date())
        asynchronously(access: .write, moc: self.moc) { return try access.create(from: dirToBeCreated, with: parentId) }

        let result = asynchronously(access: .read, moc: self.moc) { return try access.read(id: dirToBeCreated.id) }

        XCTAssertNotNil(result)

        XCTAssertEqual(result!.id, dirToBeCreated.id)
        XCTAssertEqual(result!.name, dirToBeCreated.name)
        XCTAssertEqual(result!.created, dirToBeCreated.created)
    }

    func testDeleteDirectory() {
        let directoryToBeDeleted = DirectoryVM.stub
        let unAffectedDirectory1 = DirectoryVM.stub
        let unaffectedDirectory2 = DirectoryVM.stub
        let access = DirectoryAccess(using: self.moc).stub(with: [ unAffectedDirectory1, directoryToBeDeleted, unaffectedDirectory2])

        asynchronously(access: .write, moc: self.moc) { try access.delete(directory: directoryToBeDeleted) }

        let directoryPlaceholder = asynchronously(access: .read, moc: self.moc) { return try access.read(id: directoryToBeDeleted.id) }

        XCTAssertNil(directoryPlaceholder)

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
        let parent = DirectoryVM.fresh(name: "Documents", created: Date())
        let newParent = DirectoryVM.fresh(name: "Pictures", created: Date())
        let child = DirectoryVM.fresh(name: "Best Dogs", created: Date())
        let access = DirectoryAccess(using: self.moc).stub(with: [newParent, child], to: parent.id)

        asynchronously(access: .write, moc: self.moc) { try access.reparent(from: parent.id,
                                                             node: child,
                                                             to: newParent.id) }

        let children = asynchronously(access: .read, moc: self.moc) { return try access.children(of: newParent.id) }

        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children[0].id, child.id)
    }
}
