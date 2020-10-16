//
//  FileBrowserBoundaryTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 15..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData
import Combine
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

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc))

        _ = FolderBrowserViewModel.root(defaults: defaults, access: access)
            .flatMap { vm -> AnyPublisher<DirectoryStoreLookupResult?, Error> in
                XCTAssertEqual(vm.nodes.count, 0)
                XCTAssertEqual(vm.title, "Documents")

                let rootId: String = defaults.withDefault(.rootDirectoryId, default: "Not an id")
                XCTAssertNotEqual(rootId, "Not an id")

                let id = UUID(uuidString: rootId)!

                return access.read(id: ID(id))
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootDir in
                XCTAssertNotNil(rootDir)

                let rootId: String = defaults.withDefault(.rootDirectoryId, default: "Not an id")
                let id = UUID(uuidString: rootId)!
                XCTAssertEqual(rootDir!.id, ID(id))

        })
    }

    func testCreateRootFileBrowser () {
        let defaults = UserDefaults.mock(name: #file)

        let defaultDirectoryChild = DirectoryStoreDescription.stub
        let defaultDocumentChild =
            DocumentStoreDescription(id: ID(UUID()),
                                     lastModified: Date(),
                                     name: "CV",
                                     thumbnail: .checkmark,
                                     root: NoteLevelDescription.stub(parent: nil))

        let rootDirId = UUID()
        let defaultRootDir =
            DirectoryStoreDescription.stub(id: rootDirId,
                                           documents: [ defaultDocumentChild ],
                                           directories: [ defaultDirectoryChild ])

        let access =
            DirectoryAccessImpl(access: DBAccess(moc: moc))
                .stub(root: defaultRootDir)

        defaults.set(rootDirId, forKey: UserDefaultsKey.rootDirectoryId.rawValue)

        _ = FolderBrowserViewModel.root(defaults: defaults, access: access)
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { vm in
                    XCTAssertEqual(vm.nodes.count, 2)
                    XCTAssertEqual(vm.title, defaultRootDir.name)

                    switch vm.nodes[0] {
                    case .directory(let dir):
                        XCTAssertEqual(dir.store, defaultDirectoryChild.id)
                    default:
                        XCTFail("First child should be directory")
                    }

                    switch vm.nodes[1] {
                    case .file(let file):
                        XCTAssertEqual(file.store, defaultDocumentChild.id)
                    default:
                        XCTFail("Second child should be document")
                    }
            })
    }

    func testReadNoteModel() {
        let rootLevel = NoteLevelDescription.stub(parent: nil)

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Women on Mars",
                                                thumbnail: .checkmark,
                                                root: rootLevel)

        let rootId = UUID()
        let access =  DirectoryAccessImpl(access: DBAccess(moc: self.moc))
            .stub(root: DirectoryStoreDescription.stub(id: rootId,
                                                       documents: [ document ],
                                                       directories: []))

        _ = access.noteModel(of: document.id)
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { data in
                    XCTAssertNotNil(data)
                    XCTAssertEqual(data!.id, rootLevel.id)
                    XCTAssertEqual(data!.drawing, rootLevel.drawing)
                    XCTAssertEqual(data!.frame, rootLevel.frame)
            })
    }

    func testCreateFile() {
        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [root.id: root])

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [],
                                        access: access)

        vm.process(command: .createFile(preview: .checkmark))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(access.documents.count, 1)
        XCTAssertEqual(access.directories.count, 1)
    }

    func testCreateDirectory() {
        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [root.id: root])

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [],
                                        access: access)

        vm.process(command: .createDirectory)

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(access.documents.count, 0)
        XCTAssertEqual(access.directories.count, 2)
    }

    func testUpdateFileName() {
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           root: NoteLevelDescription.stub(parent: nil))

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [doc.id: doc],
                                         directories: [root.id: root])

        let file = FileVM(id: UUID(),
                          store: doc.id,
                          preview: doc.thumbnail,
                          name: doc.name,
                          lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: root.id,
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

        XCTAssertNotNil(access.documents[doc.id])
        XCTAssertEqual(access.documents[doc.id]!.name, newName)
    }

    func testUpdateDirectoryName() {
        let dir = DirectoryStoreDescription(id: ID(UUID()),
                                            created: Date(),
                                            name: "Old name",
                                            documents: [],
                                            directories: [])

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [dir])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [
                                            root.id: root,
                                            dir.id: dir ])

        let dirVM = DirectoryVM(id: UUID(), store: dir.id, name: dir.name, created: dir.created)
        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ .directory(dirVM) ],
                                        access: access)

        let newName = "New Name"
        vm.process(command: .rename(.directory(dirVM), to: newName))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertEqual(vm.nodes.first!.name, newName)
        XCTAssertEqual(access.documents.count, 0)
        XCTAssertEqual(access.directories.count, 2)
        XCTAssertEqual(access.directories[dir.id]!.name, newName)
    }

    func testReparentDirectory() {
        let dir1 = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Directory 1",
                                             documents: [],
                                             directories: [])

        let dir2 = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Directory 2",
                                             documents: [],
                                             directories: [])

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [dir1, dir2])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [
                                            root.id: root,
                                            dir1.id: dir1,
                                            dir2.id: dir2 ])

        let dir1VM = DirectoryVM(id: UUID(),
                                 store: dir1.id,
                                 name: dir1.name,
                                 created: dir1.created)

        let dir2VM = DirectoryVM(id: UUID(),
                                 store: dir2.id,
                                 name: dir2.name,
                                 created: dir2.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
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
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           root: NoteLevelDescription.stub(parent: nil))

        let dir2 = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Directory 2",
                                             documents: [],
                                             directories: [])

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [dir2])

        let access = DirectoryAccessMock(documents: [doc.id: doc],
                                         directories: [
                                            root.id: root,
                                            dir2.id: dir2 ])

        let file = FileVM(id: UUID(),
                          store: doc.id,
                          preview: doc.thumbnail,
                          name: doc.name,
                          lastModified: doc.lastModified)

        let dir2VM = DirectoryVM(id: UUID(),
                                 store: dir2.id,
                                 name: dir2.name,
                                 created: dir2.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
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
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           root: NoteLevelDescription.stub(parent: nil))

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [doc.id: doc],
                                         directories: [root.id: root])

        let file = FileVM(id: UUID(),
                          store: doc.id,
                          preview: doc.thumbnail,
                          name: doc.name,
                          lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ .file(file) ],
                                        access: access)

        vm.process(command: .delete(.file(file)))

        XCTAssert(vm.nodes.isEmpty)
        XCTAssertEqual(access.documents.count, 0)
        XCTAssertEqual(access.directories.count, 1)
    }

    func testDeleteDirectory() {
        let dir = DirectoryStoreDescription(id: ID(UUID()),
                                            created: Date(),
                                            name: "Old name",
                                            documents: [],
                                            directories: [])

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [],
                                             directories: [dir])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [
                                            root.id: root,
                                            dir.id: dir ])

        let dirVM = DirectoryVM(id: UUID(),
                                store: dir.id,
                                name: dir.name,
                                created: dir.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ .directory(dirVM) ],
                                        access: access)

        vm.process(command: .delete(.directory(dirVM)))

        XCTAssert(vm.nodes.isEmpty)
        XCTAssertEqual(access.directories.count, 1)
        XCTAssertEqual(access.documents.count, 0)
    }
}
