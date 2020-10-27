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

// swiftlint:disable type_body_length
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
                                     imageDrawer: [],
                                     levelDrawer: [],
                                     imageTrash: [],
                                     levelTrash: [],
                                     root: NoteLevelDescription.stub(parent: nil))

        let rootDirId = UUID()
        let defaultRootDir =
            DirectoryStoreDescription.stub(id: rootDirId,
                                           documents: [ defaultDocumentChild ],
                                           directories: [ defaultDirectoryChild ])

        defaults.set(rootDirId, forKey: UserDefaultsKey.rootDirectoryId.rawValue)

        _ =
            DirectoryAccessImpl(access: DBAccess(moc: moc))
                .stubF(root: defaultRootDir)
                .flatMap { access in
                    FolderBrowserViewModel.root(defaults: defaults, access: access)
            }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
                   receiveError: { XCTFail($0.localizedDescription) },
                   receiveValue: { vm in
                    XCTAssertEqual(vm.nodes.count, 2)
                    XCTAssertEqual(vm.title, defaultRootDir.name)
                    XCTAssertTrue(vm.nodes[0].storeEquals(defaultDirectoryChild.id))
                    XCTAssertTrue(vm.nodes[1].storeEquals(defaultDocumentChild.id))
            })
    }

    func testReadNoteModel() {
        let rootLevel = NoteLevelDescription.stub(parent: nil)

        let document = DocumentStoreDescription(id: ID(UUID()),
                                                lastModified: Date(),
                                                name: "Women on Mars",
                                                thumbnail: .checkmark,
                                                imageDrawer: [],
                                                levelDrawer: [],
                                                imageTrash: [],
                                                levelTrash: [],
                                                root: rootLevel)

        let rootId = UUID()
        _ =  DirectoryAccessImpl(access: DBAccess(moc: self.moc))
            .stubF(root: DirectoryStoreDescription.stub(id: rootId,
                                                        documents: [ document ],
                                                        directories: []))
            .flatMap { access in
                access.noteModel(of: document.id)
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { data in
                XCTAssertNotNil(data)
                XCTAssertEqual(data!.root.id, rootLevel.id)
                XCTAssertEqual(data!.root.drawing, rootLevel.drawing)
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

        let id: DocumentID = ID(UUID())
        let name = "Untitled"
        let preview: UIImage = .checkmark
        let lastModified = Date()
        _ = vm.createFile(id: id, name: name, preview: preview, lastModified: lastModified)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription)},
                  receiveValue: { _ in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(vm.nodes.first!.store, .document(id))
                    XCTAssertEqual(vm.nodes.first!.preview.image, preview)
                    XCTAssertEqual(vm.nodes.first!.lastModified, lastModified)
                    XCTAssertEqual(vm.nodes.first!.name, name)
                    XCTAssertEqual(access.documents.count, 1)
                    XCTAssertEqual(access.directories.count, 1)
            })
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

        let id: DirectoryID = ID(UUID())
        let name = "Untitled"
        let lastModified = Date()
        _ = vm.createFolder(id: id, created: lastModified, name: name)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription)},
                  receiveValue: { _ in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(vm.nodes.first!.store, .directory(id))
                    XCTAssertEqual(vm.nodes.first!.lastModified, lastModified)
                    XCTAssertEqual(vm.nodes.first!.name, name)
                    XCTAssertEqual(access.documents.count, 0)
                    XCTAssertEqual(access.directories.count, 2)
            })
    }

    func testUpdateFileName() {
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           imageDrawer: [],
                                           levelDrawer: [],
                                           imageTrash: [],
                                           levelTrash: [],
                                           root: NoteLevelDescription.stub(parent: nil))

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [doc.id: doc],
                                         directories: [root.id: root])

        let file = FolderBrowserNode(id: UUID(),
                                     store: .document(doc.id),
                                     preview: CodableImage(wrapping: doc.thumbnail),
                                     name: doc.name,
                                     lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ file ],
                                        access: access)

        let newName = "New Name"
        _ = vm.rename(node: file, to: newName)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription)},
                  receiveValue: { _ in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(access.directories.count, 1)
                    XCTAssertEqual(access.documents.count, 1)

                    XCTAssertNotNil(vm.nodes.first(where: { $0.id == file.id }))
                    XCTAssertEqual(vm.nodes.first(where: { $0.id == file.id })!.name, newName)

                    XCTAssertNotNil(access.documents[doc.id])
                    XCTAssertEqual(access.documents[doc.id]!.name, newName)
            })
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

        let dirVM = FolderBrowserNode(id: UUID(),
                                      store: .directory(dir.id),
                                      preview: CodableImage(wrapping: .checkmark),
                                      name: dir.name,
                                      lastModified: dir.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ dirVM ],
                                        access: access)

        let newName = "New Name"
        _ = vm.rename(node: dirVM, to: newName)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription)},
                  receiveValue: { _ in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(vm.nodes.first!.name, newName)
                    XCTAssertEqual(access.documents.count, 0)
                    XCTAssertEqual(access.directories.count, 2)
                    XCTAssertEqual(access.directories[dir.id]!.name, newName)
            })
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

        let dir1VM = FolderBrowserNode(id: UUID(),
                                       store: .directory(dir1.id),
                                       preview: CodableImage(wrapping: .checkmark),
                                       name: dir1.name,
                                       lastModified: dir1.created)

        let dir2VM = FolderBrowserNode(id: UUID(),
                                       store: .directory(dir2.id),
                                       preview: CodableImage(wrapping: .checkmark),
                                       name: dir2.name,
                                       lastModified: dir2.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ dir1VM, dir2VM ],
                                        access: access)

        _ = vm.move(node: dir1VM, to: dir2.id)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription)},
                  receiveValue: { _ in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssert(access.documents.isEmpty)
                    XCTAssertEqual(access.directories.count, 3)
            })
    }

    func testReparentDocument() {
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           imageDrawer: [],
                                           levelDrawer: [],
                                           imageTrash: [],
                                           levelTrash: [],
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

        let file = FolderBrowserNode(id: UUID(),
                                     store: .document(doc.id),
                                     preview: CodableImage(wrapping: doc.thumbnail),
                                     name: doc.name,
                                     lastModified: doc.lastModified)

        let dir2VM = FolderBrowserNode(id: UUID(),
                                       store: .directory(dir2.id),
                                       preview: CodableImage(wrapping: .checkmark),
                                       name: dir2.name,
                                       lastModified: dir2.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ dir2VM, file ],
                                        access: access)

        _ = vm.move(node: file, to: dir2.id)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { _ in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(access.documents.count, 1)
                    XCTAssertEqual(access.directories.count, 2)
            })
    }

    func testDeleteFile() {
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Integration tests",
                                           thumbnail: .checkmark,
                                           imageDrawer: [],
                                           levelDrawer: [],
                                           imageTrash: [],
                                           levelTrash: [],
                                           root: NoteLevelDescription.stub(parent: nil))

        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Tests",
                                             documents: [ doc ],
                                             directories: [])

        let access = DirectoryAccessMock(documents: [doc.id: doc],
                                         directories: [root.id: root])

        let file = FolderBrowserNode(id: UUID(),
                                     store: .document(doc.id),
                                     preview: CodableImage(wrapping: doc.thumbnail),
                                     name: doc.name,
                                     lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ file ],
                                        access: access)

        _ = vm.delete(node: file)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { _ in
                    XCTAssert(vm.nodes.isEmpty)
                    XCTAssertEqual(access.documents.count, 0)
                    XCTAssertEqual(access.directories.count, 1)
            })
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

        let dirVM = FolderBrowserNode(id: UUID(),
                                      store: .directory(dir.id),
                                      preview: CodableImage(wrapping: .checkmark),
                                      name: dir.name,
                                      lastModified: dir.created)

        let vm = FolderBrowserViewModel(directoryId: root.id,
                                        name: root.name,
                                        nodes: [ dirVM ],
                                        access: access)

        _ = vm.delete(node: dirVM)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { _ in
                    XCTAssert(vm.nodes.isEmpty)
                    XCTAssertEqual(access.directories.count, 1)
                    XCTAssertEqual(access.documents.count, 0)
            })
    }
}
