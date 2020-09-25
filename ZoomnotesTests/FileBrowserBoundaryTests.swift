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

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
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
        self.continueAfterFailure = false

        let defaults = UserDefaults.mock(name: #file)

        let defaultDirectoryChild = DirectoryStoreDescription.stub
        let defaultDocumentChild =
            DocumentStoreDescription(data: "dummy",
                                     id: UUID(),
                                     lastModified: Date(),
                                     name: "CV",
                                     thumbnail: .checkmark)

        let defaultRootDir =
            DirectoryStoreDescription.stub(documents: [ defaultDocumentChild ],
                                           directories: [ defaultDirectoryChild ])

        _ = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                           file: DocumentAccessImpl(using: self.moc))
            .stub(root: defaultRootDir)

        defaults.set(defaultRootDir.id, forKey: UserDefaultsKey.rootDirectoryId.rawValue)

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

        let document = DocumentStoreDescription(data: noteData,
                                                id: noteId,
                                                lastModified: Date(),
                                                name: noteTitle,
                                                thumbnail: .checkmark)

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [ document ],
                                                       directories: []))

        let data = asynchronously(access: .read, moc: self.moc) { try access.file.noteModel(of: noteId) }
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

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [
                DocumentStoreDescription(data: noteData,
                                         id: noteId,
                                         lastModified: Date(),
                                         name: noteTitle,
                                         thumbnail: .checkmark)
                ],
                                                       directories: []))

        let data = asynchronously(access: .read, moc: self.moc) {
            try access.file.noteModel(of: noteId)
        }

        XCTAssertNotNil(data)
        XCTAssertEqual(data!.id, noteId)
        XCTAssertEqual(data!.title, noteTitle)

        let newTitle = "Renamed notes"

        note.title = newTitle

        // swiftlint:disable:next force_try
        let seri = try! note.serialize()

        asynchronously(access: .write, moc: self.moc) {
            try access.file.updateData(of: noteId, with: seri)
        }

        let data2 = asynchronously(access: .read, moc: self.moc) {
            try access.file.noteModel(of: noteId)
        }

        XCTAssertNotNil(data2)
        XCTAssertEqual(data2!.id, noteId)
        XCTAssertEqual(data2!.title, newTitle)
    }
}
