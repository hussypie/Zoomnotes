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

class FileBrowserDBReadingTests: XCTestCase {
    func testCreateFile() {
        let vm = FolderBrowserViewModel.stub

        vm.process(command: .createFile)

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
        XCTAssertTrue(dir.nodes.isEmpty)
    }

    func testDeleteNode() {
        let node: Node = .file(FileVM(preview: .remove, name: "Stuff I'd rather forget", lastModified: Date().advanced(by: -24*60*60)))
        let nodes: [Node] = [
            node,
            .file(FileVM(preview: .actions, name: "Best Schwarzenegger Movies", lastModified: Date())),
            .file(FileVM(preview: .checkmark, name: "TODOs", lastModified: Date()))
        ]
        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .delete(node))

        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testDeleteNodeNonExistentNode() {
        let node: Node = .file(FileVM(preview: .remove, name: "Stuff I'd rather forget", lastModified: Date().advanced(by: -24*60*60)))

        let nodes: [Node] = [
            .file(FileVM(preview: .actions, name: "Best Schwarzenegger Movies", lastModified: Date())),
            .file(FileVM(preview: .checkmark, name: "TODOs", lastModified: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .delete(node))

        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
    }

    func testRenameNode() {
        let node: Node = .file(FileVM(preview: .remove, name: "Stuff I'd rather forget", lastModified: Date().advanced(by: -24*60*60)))

        let nodes: [Node] = [
            node,
            .file(FileVM(preview: .actions, name: "Best Schwarzenegger Movies", lastModified: Date())),
            .file(FileVM(preview: .checkmark, name: "TODOs", lastModified: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .rename(node, to: "Stuff I can live with"))

        vm.nodes
            .filter { $0.id == node.id }
            .first
            .map { XCTAssert($0.name == "Stuff I can live with") }
    }

    func testRenameNodeNonExistentNode() {
        let node: Node = .file(FileVM(preview: .remove, name: "Stuff I'd rather forget", lastModified: Date().advanced(by: -24*60*60)))

        let nodes: [Node] = [
            .file(FileVM(preview: .actions, name: "Best Schwarzenegger Movies", lastModified: Date())),
            .file(FileVM(preview: .checkmark, name: "TODOs", lastModified: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        vm.process(command: .rename(node, to: "Stuff I can live with"))

        vm.nodes
            .filter { $0.id == node.id }
            .first
            .map { XCTAssert($0.name == "Stuff I can live with") }
    }

    func testMoveNodeToDirectory() {
        let node: Node = .file(FileVM(preview: .remove, name: "Stuff I'd rather forget", lastModified: Date().advanced(by: -24*60*60)))

        let dir: DirectoryVM = DirectoryVM(name: "Don't look here", created: Date(), nodes: [])

        let nodes: [Node] = [
            node,
            .directory(dir),
            .file(FileVM(preview: .actions, name: "Best Schwarzenegger Movies", lastModified: Date())),
            .file(FileVM(preview: .checkmark, name: "TODOs", lastModified: Date()))
        ]

        let vm = FolderBrowserViewModel.stub(nodes: nodes)

        let originalNodeCount = vm.nodes.count

        vm.process(command: .move(node, to: dir))

        XCTAssert(vm.nodes.count == originalNodeCount - 1)
        XCTAssert(vm.nodes.filter { $0.id == node.id }.isEmpty)
        XCTAssert(dir.nodes.count == 1)
        guard let nodeInDir = dir.nodes.filter({ $0.id == node.id }).first else {
            XCTFail("Moved node not in destination folder")
            return
        }
        XCTAssert(node.id == nodeInDir.id)
    }
}
