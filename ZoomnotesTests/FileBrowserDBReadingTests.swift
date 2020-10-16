//
//  FileBrowserDBReadingTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 09..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData
@testable import Zoomnotes

extension FileVM {
    static func fresh(preview: UIImage, name: String, created: Date) -> FileVM {
        return FileVM(id: UUID(),
                      store: ID(UUID()),
                      preview: preview,
                      name: name,
                      lastModified: created)
    }
}

extension DirectoryVM {
    static func fresh(name: String, created: Date) -> DirectoryVM {
        return DirectoryVM(id: UUID(),
                           store: ID(UUID()),
                           name: name,
                           created: created)
    }
}

class FileBrowserVMTests: XCTestCase {
    func testCreateFile() {
        let vm = FolderBrowserViewModel.stub

        vm.process(command: .createFile(preview: .checkmark))

        XCTAssertTrue(vm.nodes.count == 1)

        guard case .file(let newFile) = vm.nodes[0] else {
            XCTFail("Newly created node has to be a file")
            return
        }

        XCTAssertTrue(newFile.name == "Untitled")
    }

    func testCreateFolder() {
        let vm = FolderBrowserViewModel.stub

        vm.process(command: .createDirectory)

        XCTAssertTrue(vm.nodes.count == 1)

        guard case .directory(let dir) = vm.nodes[0] else {
            XCTFail("Newly created node has to be a directory")
            return
        }

        XCTAssertTrue(dir.name == "Untitled")
    }

    func testDeleteNode() {
        let node: FolderBrowserViewModel.Node =
            .file(
                FileVM.fresh(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60))
        )
        let nodes: [FolderBrowserViewModel.Node] = [
            node,
            .file(FileVM.fresh(preview: .actions, name: "Best Schwarzenegger Movies", created: Date())),
            .file(FileVM.fresh(preview: .checkmark, name: "TODOs", created: Date()))
        ]
        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .delete(node))

        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testDeleteNodeNonExistentNode() {
        let node: FolderBrowserViewModel.Node =
            .file(
                FileVM.fresh(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60)))

        let nodes: [FolderBrowserViewModel.Node] = [
            .file(FileVM.fresh(preview: .actions, name: "Best Schwarzenegger Movies", created: Date())),
            .file(FileVM.fresh(preview: .checkmark, name: "TODOs", created: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .delete(node))

        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testRenameNode() {
        let node: FolderBrowserViewModel.Node =
            .file(
                FileVM.fresh(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60)))

        let nodes: [FolderBrowserViewModel.Node] = [
            node,
            .file(FileVM.fresh(preview: .actions, name: "Best Schwarzenegger Movies", created: Date())),
            .file(FileVM.fresh(preview: .checkmark, name: "TODOs", created: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .rename(node, to: "Stuff I can live with"))

        vm.nodes
            .filter { $0.id == node.id }
            .first
            .map { XCTAssert($0.name == "Stuff I can live with") }
    }

    func testRenameNodeNonExistentNode() {
        let node: FolderBrowserViewModel.Node = .file(
            FileVM.fresh(preview: .remove,
                         name: "Stuff I'd rather forget",
                         created: Date().advanced(by: -24*60*60)))

        let nodes: [FolderBrowserViewModel.Node] = [
            .file(FileVM.fresh(preview: .actions, name: "Best Schwarzenegger Movies", created: Date())),
            .file(FileVM.fresh(preview: .checkmark, name: "TODOs", created: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .rename(node, to: "Stuff I can live with"))

        vm.nodes
            .filter { $0.id == node.id }
            .first
            .map { XCTAssert($0.name == "Stuff I can live with") }
    }

    func testMoveNodeToDirectory() {
        let node: FolderBrowserViewModel.Node =
            .file(
                FileVM.fresh(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60)))

        let dir: DirectoryVM = DirectoryVM.fresh(name: "Don't look here", created: Date())

        let nodes: [FolderBrowserViewModel.Node] = [
            node,
            .directory(dir),
            .file(FileVM.fresh(preview: .actions, name: "Best Schwarzenegger Movies", created: Date())),
            .file(FileVM.fresh(preview: .checkmark, name: "TODOs", created: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        let originalNodeCount = vm.nodes.count

        vm.process(command: .move(node, to: dir))

        XCTAssert(vm.nodes.count == originalNodeCount - 1)
        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testProduceCorrectSubfolderVM() {
        let dir = DirectoryStoreDescription(id: ID(UUID()),
                                            created: Date(),
                                            name: "Horror",
                                            documents: [],
                                            directories: [])

        let rootDir = DirectoryStoreDescription(id: ID(UUID()),
                                                created: Date(),
                                                name: "Movies",
                                                documents: [],
                                                directories: [dir])

        let access = DirectoryAccessMock(documents: [:],
                                         directories: [
                                            rootDir.id: rootDir,
                                            dir.id: dir ])

        let dirVM = DirectoryVM(id: UUID(),
                                store: dir.id,
                                name: dir.name,
                                created: dir.created)

        let vm = FolderBrowserViewModel(directoryId: rootDir.id,
                                        name: rootDir.name,
                                        nodes: [ .directory(dirVM) ],
                                        access: access)

        _ = vm.subFolderBrowserVM(for: dirVM)
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { childVM in
                    XCTAssertEqual(childVM.title, dirVM.name)
                    XCTAssertEqual(childVM.nodes.count, dir.directories.count + dir.documents.count)
            })
    }

    func testProduceCorrectNoteEditorVM() {
        let doc = DocumentStoreDescription(id: ID(UUID()),
                                           lastModified: Date(),
                                           name: "Best Schwarzenegger movies",
                                           thumbnail: .actions,
                                           root: NoteLevelDescription.stub(parent: nil))

        let rootDir = DirectoryStoreDescription(id: ID(UUID()),
                                                created: Date(),
                                                name: "Movies",
                                                documents: [doc],
                                                directories: [])

        let access = DirectoryAccessMock(documents: [doc.id: doc],
                                         directories: [rootDir.id: rootDir])

        let file = FileVM(id: UUID(),
                          store: doc.id,
                          preview: doc.thumbnail,
                          name: doc.name,
                          lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: rootDir.id,
                                        name: rootDir.name,
                                        nodes: [ .file(file) ],
                                        access: access)

        _ = vm.noteEditorVM(for: file)
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { noteVM in
                    XCTAssertNotNil(noteVM)
                    XCTAssertEqual(noteVM!.drawing, doc.root.drawing)
                    XCTAssertEqual(noteVM!.title, doc.name)
            })
    }
}
