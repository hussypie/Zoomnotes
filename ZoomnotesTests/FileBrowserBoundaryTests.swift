//
//  FileBrowserBoundaryTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData
import PencilKit

@testable import Zoomnotes

class FileBrowserDBIntegrationTests: XCTestCase {

    let moc = NSPersistentContainer.inMemory(name: "Zoomnotes").viewContext

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    func testCreateRootFoleBrowserVMIfNotExists() {
        let defaults = UserDefaults.mock(name: #file)

        let access = DirectoryAccessImpl(using: self.moc)

        let vm = FolderBrowserViewModel.root(defaults: defaults, access: access)

        XCTAssertEqual(vm.nodes.count, 0)
        XCTAssertEqual(vm.title, "Documents")

        let rootId: String = defaults.withDefault(.rootDirectoryId, default: "Not an id")
        XCTAssertNotEqual(rootId, "Not an id")

        let id = UUID(uuidString: rootId)!

        let rootDir = asynchronously(access: .read, moc: self.moc) {
            return try access.read(id: DirectoryStoreId(id: id))
        }

        XCTAssertNotNil(rootDir)
        XCTAssertEqual(rootDir!.id.id, id)
    }

    func testCreateRootFileBrowser () {
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

        let access =
            DirectoryAccessImpl(using: self.moc)
                .stub(root: defaultRootDir)

        defaults.set(defaultRootDir.id.id, forKey: UserDefaultsKey.rootDirectoryId.rawValue)

        let vm = FolderBrowserViewModel.root(defaults: defaults, access: access)

        XCTAssertEqual(vm.nodes.count, 2)
        XCTAssertEqual(vm.title, defaultRootDir.name)
        XCTAssertEqual(vm.nodes[0].id, defaultDirectoryChild.id.id)
        XCTAssertEqual(vm.nodes[1].id, defaultDocumentChild.id.id)
    }

    func testReadNoteModel() {
        let rootLevel = NoteLevelDescription.stub(parent: nil)

        let document = DocumentStoreDescription(id: UUID(),
                                                lastModified: Date(),
                                                name: "Women on Mars",
                                                thumbnail: .checkmark,
                                                root: rootLevel)

        let access =  DirectoryAccessImpl(using: self.moc)
            .stub(root: DirectoryStoreDescription.stub(documents: [ document ],
                                                       directories: []))

        let data = asynchronously(access: .read, moc: self.moc) { try access.noteModel(of: document.id) }
        XCTAssertNotNil(data)
        XCTAssertEqual(data!.id, rootLevel.id)
        XCTAssertEqual(data!.drawing, rootLevel.drawing)
        XCTAssertEqual(data!.frame, rootLevel.frame)
    }

    func testCreateFile() {
        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [root.id.id: root])

        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [],
                                        access: access)

        vm.process(command: .createFile(preview: .checkmark))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(access.documents.count, 1)
        XCTAssertEqual(access.directories.count, 1)
    }

    func testCreateDirectory() {
        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [root.id.id: root])

        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [],
                                        access: access)

        vm.process(command: .createDirectory)

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(access.documents.count, 0)
        XCTAssertEqual(access.directories.count, 2)
    }

    func testUpdateFileName() {
        let doc = DocumentStoreDescription(id: UUID(),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           root: NoteLevelDescription.stub(parent: nil))

        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [doc.id.id: doc],
                                         directories: [root.id.id: root])

        let file = FileVM(id: doc.id.id,
                          preview: doc.thumbnail,
                          name: doc.name,
                          lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [ .file(file) ],
                                        access: access)

        let newName = "New Name"
        vm.process(command: .rename(.file(file), to: newName))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(access.directories.count, 1)
        XCTAssertEqual(access.documents.count, 1)

        XCTAssertNotNil(vm.nodes.first(where: { $0.id == file.id }))
        XCTAssertEqual(vm.nodes.first(where: { $0.id == file.id })!.name, newName)

        XCTAssertNotNil(access.documents[doc.id.id])
        XCTAssertEqual(access.documents[doc.id.id]!.name, newName)
    }

    func testUpdateDirectoryName() {
        let dir = DirectoryStoreDescription(id: UUID(),
                                            created: Date(),
                                            name: "Old name",
                                            documents: [],
                                            directories: [])

        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [dir])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [
                                            root.id.id: root,
                                            dir.id.id: dir ])

        let dirVM = DirectoryVM(id: dir.id.id, name: dir.name, created: dir.created)
        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [ .directory(dirVM) ],
                                        access: access)

        let newName = "New Name"
        vm.process(command: .rename(.directory(dirVM), to: newName))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(vm.nodes.first!.name, newName)
        XCTAssertEqual(access.documents.count, 0)
        XCTAssertEqual(access.directories.count, 2)
        XCTAssertEqual(access.directories[dir.id.id]!.name, newName)
    }

    func testReparentDirectory() {
        let dir1 = DirectoryStoreDescription(id: UUID(),
                                            created: Date(),
                                            name: "Directory 1",
                                            documents: [],
                                            directories: [])

        let dir2 = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Directory 2",
                                             documents: [],
                                             directories: [])

        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [dir1, dir2])

        let access = DirectoryAccessMock(documents: [:],
                                        directories: [
                                            root.id.id: root,
                                            dir1.id.id: dir1,
                                            dir2.id.id: dir2 ])

        let dir1VM = DirectoryVM(id: dir1.id.id, name: dir1.name, created: dir1.created)
        let dir2VM = DirectoryVM(id: dir2.id.id, name: dir2.name, created: dir2.created)

        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [
                                            .directory(dir1VM),
                                            .directory(dir2VM)
            ],
                                        access: access)

        vm.process(command: .move(.directory(dir1VM), to: dir2VM))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssert(access.documents.isEmpty)
        XCTAssertEqual(access.directories.count, 3)
    }

    func testReparentDocument() {
        let doc = DocumentStoreDescription(id: UUID(),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           root: NoteLevelDescription.stub(parent: nil))

        let dir2 = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Directory 2",
                                             documents: [],
                                             directories: [])

        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [dir2])

        let access = DirectoryAccessMock(documents: [doc.id.id: doc],
                                        directories: [
                                            root.id.id: root,
                                            dir2.id.id: dir2 ])

        let file = FileVM(id: doc.id.id, preview: doc.thumbnail, name: doc.name, lastModified: doc.lastModified)
        let dir2VM = DirectoryVM(id: dir2.id.id, name: dir2.name, created: dir2.created)

        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [
                                            .file(file),
                                            .directory(dir2VM)
            ],
                                        access: access)

        vm.process(command: .move(.file(file), to: dir2VM))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(access.documents.count, 1)
        XCTAssertEqual(access.directories.count, 2)
    }

    func testDeleteFile() {
        let doc = DocumentStoreDescription(id: UUID(),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           root: NoteLevelDescription.stub(parent: nil))

        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [doc.id.id: doc],
                                         directories: [root.id.id: root])

        let file = FileVM(id: doc.id.id,
                          preview: doc.thumbnail,
                          name: doc.name,
                          lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [ .file(file) ],
                                        access: access)

        vm.process(command: .delete(.file(file)))

        XCTAssert(vm.nodes.isEmpty)
        XCTAssertEqual(access.documents.count, 0)
        XCTAssertEqual(access.directories.count, 1)
    }

    func testDeleteDirectory() {
        let dir = DirectoryStoreDescription(id: UUID(),
                                            created: Date(),
                                            name: "Old name",
                                            documents: [],
                                            directories: [])

        let root = DirectoryStoreDescription(id: UUID(),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [dir])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [
                                            root.id.id: root,
                                            dir.id.id: dir ])

        let dirVM = DirectoryVM(id: dir.id.id, name: dir.name, created: dir.created)
        let vm = FolderBrowserViewModel(directoryId: root.id.id,
                                        name: root.name,
                                        nodes: [ .directory(dirVM) ],
                                        access: access)

        vm.process(command: .delete(.directory(dirVM)))

        XCTAssert(vm.nodes.isEmpty)
        XCTAssertEqual(access.directories.count, 1)
        XCTAssertEqual(access.documents.count, 0)
    }
}
