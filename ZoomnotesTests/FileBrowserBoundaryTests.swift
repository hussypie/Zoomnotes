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

    func testCreateRootFoleBrowserVM() {
//        let defaults = UserDefaults()
//
//        let vm = FolderBrowserViewModel.root(defaults: defaults, using: self.moc)
//
//        XCTAssertEqual(vm.nodes.count, 0)
//        XCTAssertEqual(vm.title, "Documents")
//
//        let rootId: String = defaults.withDefault(.rootDirectoryId, default: "Not an id")
//        XCTAssertNotEqual(rootId, "Not an id")

        XCTFail("Not implemented correctly")
    }

    func testCreateRootFileBrowser () {
        XCTFail("Not implemented")
    }

    func testReadFolderByParentId() {
        XCTFail("Not implemented")
    }

    func testReadNoteModel() {
        XCTFail("Not implemented")
    }
}
