//
//  FileBrowserBoundaryTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData

@testable import Zoomnotes

class FileBrowserBoundaryTests: XCTestCase {

    let moc = NSPersistentContainer.inMemory(name: "Zoomnotes").viewContext

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

    func testCreateRootFoleBrowserVMIfNotExists() {
        let defaults = UserDefaults(suiteName: #file)!
        defaults.removePersistentDomain(forName: #file)

        let vm = FolderBrowserViewModel.root(defaults: defaults, using: self.moc)

        XCTAssertEqual(vm.nodes.count, 0)
        XCTAssertEqual(vm.title, "Documents")

        let rootId: String = defaults.withDefault(.rootDirectoryId, default: "Not an id")
        XCTAssertNotEqual(rootId, "Not an id")
    }

    func testCreateRootFileBrowser () {
        let defaults = UserDefaults(suiteName: #file)!
        defaults.removePersistentDomain(forName: #file)

        let defaultId = UUID()
        let defaultRootDir = DirectoryVM(id: defaultId, name: "Mock Documents", created: Date())
        let defaultDirectoryChild = DirectoryVM.fresh(name: "Pages", created: Date())
        let defaultDocumentChild =
            DocumentAccess.StoreDescription(data: "dummy",
                                            id: UUID(),
                                            lastModified: Date(),
                                            name: "CV",
                                            parent: defaultRootDir.id,
                                            thumbnail: .checkmark)
        let access = CoreDataAccess(using: self.moc)

        asynchronously(access: .write) {
            try access.directory.create(from: defaultRootDir, with: defaultRootDir.id)
            try access.directory.create(from: defaultDirectoryChild, with: defaultRootDir.id)
            try access.file.create(from: defaultDocumentChild)

            defaults.set(defaultId, forKey: UserDefaultsKey.rootDirectoryId.rawValue)
        }

        let vm = FolderBrowserViewModel.root(defaults: defaults, using: self.moc)

        XCTAssertEqual(vm.nodes.count, 2)
        XCTAssertEqual(vm.title, defaultRootDir.name)
        XCTAssertEqual(vm.nodes[0].id, defaultDirectoryChild.id)
        XCTAssertEqual(vm.nodes[1].id, defaultDocumentChild.id)
    }

    func testReadNoteModel() {
        let noteId = UUID()
        let noteTitle = "Notes"

        let note = NoteModel.default(id: noteId,
                                     image: .checkmark,
                                     frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        note.title = noteTitle

        // swiftlint:disable:next force_try
        let noteData = try! note.serialize()

        let access = DocumentAccess(using: self.moc)
            .stub(with: [
                DocumentAccess.StoreDescription(data: noteData,
                                                id: noteId,
                                                lastModified: Date(),
                                                name: noteTitle,
                                                parent: UUID(),
                                                thumbnail: .checkmark)
            ])

        let data = asynchronously(access: .read) { try access.noteModel(of: noteId) }
        XCTAssertNotNil(data)
        XCTAssertEqual(data!.id, noteId)
        XCTAssertEqual(data!.title, noteTitle)
    }

    func testSaveNoteModel() {
        let noteId = UUID()
        let noteTitle = "Notes"

        let note = NoteModel.default(id: noteId,
                                     image: .checkmark,
                                     frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        note.title = noteTitle

        // swiftlint:disable:next force_try
        let noteData = try! note.serialize()

        let access = DocumentAccess(using: self.moc)
            .stub(with: [
                DocumentAccess.StoreDescription(data: noteData,
                                                id: noteId,
                                                lastModified: Date(),
                                                name: noteTitle,
                                                parent: UUID(),
                                                thumbnail: .checkmark)
            ])

        let data = asynchronously(access: .read) { try access.noteModel(of: noteId) }

        XCTAssertNotNil(data)
        XCTAssertEqual(data!.id, noteId)
        XCTAssertEqual(data!.title, noteTitle)

        let newTitle = "Renamed notes"

        note.title = newTitle

        // swiftlint:disable:next force_try
        let seri = try! note.serialize()

        asynchronously(access: .write) { try access.updateData(of: noteId, with: seri) }

        let data2 = asynchronously(access: .read) { try access.noteModel(of: noteId) }

        XCTAssertNotNil(data2)
        XCTAssertEqual(data2!.id, noteId)
        XCTAssertEqual(data2!.title, newTitle)

    }
}
