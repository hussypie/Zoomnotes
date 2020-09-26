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

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))

        let vm = FolderBrowserViewModel.root(defaults: defaults, access: access)

        XCTAssertEqual(vm.nodes.count, 0)
        XCTAssertEqual(vm.title, "Documents")

        let rootId: String = defaults.withDefault(.rootDirectoryId, default: "Not an id")
        XCTAssertNotEqual(rootId, "Not an id")

        let id = UUID(uuidString: rootId)!

        let rootDir = asynchronously(access: .read, moc: self.moc) {
            return try access.directory.read(id: id)
        }

        XCTAssertNotNil(rootDir)
        XCTAssertEqual(rootDir!.id, id)
    }

    func testCreateRootFileBrowser () {
        self.continueAfterFailure = false

        let defaults = UserDefaults.mock(name: #file)

        let defaultDirectoryChild = DirectoryStoreDescription.stub
        let defaultDocumentChild =
            DocumentStoreDescription(id: UUID(),
                                     lastModified: Date(),
                                     name: "CV",
                                     thumbnail: .checkmark,
                                     root: NoteLevelDescription.stub(parent: nil))

        let defaultRootDir =
            DirectoryStoreDescription.stub(documents: [ defaultDocumentChild ],
                                           directories: [ defaultDirectoryChild ])

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                           file: DocumentAccessImpl(using: self.moc))
            .stub(root: defaultRootDir)

        defaults.set(defaultRootDir.id, forKey: UserDefaultsKey.rootDirectoryId.rawValue)

        let vm = FolderBrowserViewModel.root(defaults: defaults, access: access)

        XCTAssertEqual(vm.nodes.count, 2)
        XCTAssertEqual(vm.title, defaultRootDir.name)
        XCTAssertEqual(vm.nodes[0].id, defaultDirectoryChild.id)
        XCTAssertEqual(vm.nodes[1].id, defaultDocumentChild.id)
    }

    func testReadNoteModel() {
        let rootLevel = NoteLevelDescription.stub(parent: nil)

        let document = DocumentStoreDescription(id: UUID(),
                                                lastModified: Date(),
                                                name: "Women on Mars",
                                                thumbnail: .checkmark,
                                                root: rootLevel)

        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: self.moc),
                                    file: DocumentAccessImpl(using: self.moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [ document ],
                                                       directories: []))

        let data = asynchronously(access: .read, moc: self.moc) { try access.file.noteModel(of: document.id) }
        XCTAssertNotNil(data)
        XCTAssertEqual(data!.id, rootLevel.id)
        XCTAssertEqual(data!.drawing, rootLevel.drawing)
        XCTAssertEqual(data!.parent, rootLevel.parent)
        XCTAssertEqual(data!.frame, rootLevel.frame)
    }
}
