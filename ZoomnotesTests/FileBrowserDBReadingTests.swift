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

extension FolderBrowserNode {
    static func directory(name: String, created: Date) -> FolderBrowserNode {
        return FolderBrowserNode(id: UUID(),
                                 store: .directory(ID(UUID())),
                                 preview: CodableImage(wrapping: .checkmark),
                                 name: name,
                                 lastModified: created)
    }

    static func document(preview: UIImage, name: String, created: Date) -> FolderBrowserNode {
        return FolderBrowserNode(id: UUID(),
                                 store: .document(ID(UUID())),
                                 preview: CodableImage(wrapping: preview),
                                 name: name,
                                 lastModified: created)
    }
}

class FileBrowserVMTests: XCTestCase {
    func testCreateFile() {
        let vm = FolderBrowserViewModel.stub

        vm.process(command: .createFile(preview: .checkmark))

        XCTAssertTrue(vm.nodes.count == 1)

        guard case .document = vm.nodes[0].store else {
            XCTFail("Newly created node has to be a file")
            return
        }

        XCTAssertTrue(vm.nodes[0].name == "Untitled")
    }

    func testCreateFolder() {
        let vm = FolderBrowserViewModel.stub

        vm.process(command: .createDirectory)

        XCTAssertTrue(vm.nodes.count == 1)

        guard case .directory = vm.nodes[0].store else {
            XCTFail("Newly created node has to be a directory")
            return
        }

        XCTAssertTrue(vm.nodes[0].name == "Untitled")
    }

    func testDeleteNode() {
        let node: FolderBrowserNode =
            FolderBrowserNode.document(preview: .remove,
                                       name: "Stuff I'd rather forget",
                                       created: Date().advanced(by: -24*60*60))
        let nodes: [FolderBrowserNode] = [
            node,
            FolderBrowserNode.document(preview: .actions, name: "Best Schwarzenegger Movies", created: Date()),
            FolderBrowserNode.document(preview: .checkmark, name: "TODOs", created: Date())
        ]
        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .delete(node))

        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testDeleteNodeNonExistentNode() {
        let node: FolderBrowserNode =

                FolderBrowserNode.document(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60))

        let nodes: [FolderBrowserNode] = [
            FolderBrowserNode.document(preview: .actions, name: "Best Schwarzenegger Movies", created: Date()),
            FolderBrowserNode.document(preview: .checkmark, name: "TODOs", created: Date())
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .delete(node))

        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testRenameNode() {
        let node: FolderBrowserNode =

                FolderBrowserNode.document(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60))

        let nodes: [FolderBrowserNode] = [
            node,
            FolderBrowserNode.document(preview: .actions, name: "Best Schwarzenegger Movies", created: Date()),
            FolderBrowserNode.document(preview: .checkmark, name: "TODOs", created: Date())
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .rename(node, to: "Stuff I can live with"))

        vm.nodes
            .filter { $0.id == node.id }
            .first
            .map { XCTAssert($0.name == "Stuff I can live with") }
    }

    func testRenameNodeNonExistentNode() {
        let node: FolderBrowserNode =
            FolderBrowserNode.document(preview: .remove,
                         name: "Stuff I'd rather forget",
                         created: Date().advanced(by: -24*60*60))

        let nodes: [FolderBrowserNode] = [
            FolderBrowserNode.document(preview: .actions, name: "Best Schwarzenegger Movies", created: Date()),
            FolderBrowserNode.document(preview: .checkmark, name: "TODOs", created: Date())
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .rename(node, to: "Stuff I can live with"))

        vm.nodes
            .filter { $0.id == node.id }
            .first
            .map { XCTAssert($0.name == "Stuff I can live with") }
    }

    func testMoveNodeToDirectory() {
        let node: FolderBrowserNode =
               FolderBrowserNode.document(preview: .remove,
                             name: "Stuff I'd rather forget",
                             created: Date().advanced(by: -24*60*60))

        let dir: FolderBrowserNode = FolderBrowserNode.directory(name: "Don't look here", created: Date())

        let nodes: [FolderBrowserNode] = [
            node,
            dir,
            FolderBrowserNode.document(preview: .actions, name: "Best Schwarzenegger Movies", created: Date()),
            FolderBrowserNode.document(preview: .checkmark, name: "TODOs", created: Date())
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        let originalNodeCount = vm.nodes.count

        let id: DirectoryID
        switch dir.store {
        case .directory(let did):
            id = did
        default:
            XCTFail("Directory id does not refer to directory")
            return
        }
        vm.process(command: .move(node, to: id))

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

        let dirVM = FolderBrowserNode(id: UUID(),
                                      store: .directory(dir.id),
                                      preview: CodableImage(wrapping: .checkmark),
                                      name: dir.name,
                                      lastModified: dir.created)

        let vm = FolderBrowserViewModel(directoryId: rootDir.id,
                                        name: rootDir.name,
                                        nodes: [ dirVM ],
                                        access: access)

        _ = vm.subFolderBrowserVM(for: dir.id, with: dirVM.name)
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

        let file = FolderBrowserNode(id: UUID(),
                                     store: .document(doc.id),
                                     preview: CodableImage(wrapping: doc.thumbnail),
                                     name: doc.name,
                                     lastModified: doc.lastModified)

        let vm = FolderBrowserViewModel(directoryId: rootDir.id,
                                        name: rootDir.name,
                                        nodes: [ file ],
                                        access: access)

        _ = vm.noteEditorVM(for: doc.id, with: file.name)
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { noteVM in
                    XCTAssertNotNil(noteVM)
                    XCTAssertEqual(noteVM!.drawing, doc.root.drawing)
                    XCTAssertEqual(noteVM!.title, doc.name)
            })
    }
}
