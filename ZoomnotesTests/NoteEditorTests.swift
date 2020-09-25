//
//  NoteEditorTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 11..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import PencilKit
@testable import Zoomnotes

//enum NoteEditorCommand {
//    case create(NoteModel.NoteLevel)
//    case remove(NoteModel.NoteLevel)
//    case move(NoteModel.NoteLevel, from: CGRect, to: CGRect)
//    case resize(NoteModel.NoteLevel, from: CGRect, to: CGRect)
//    case update(PKDrawing)
//    case refresh(CodableImage)
//    case moveToDrawer(NoteModel.NoteLevel, frame: CGRect)
//    case moveFromDrawer(NoteModel.NoteLevel, frame: CGRect)
//}

/*
    Editing:
    create:         nothing => canvas
    remove:         canvas => nothing
    move:           canvas => canvas
    moveToDrawer:   canvas => drawer
    moveFromDrawer: drawer => canvas
    resize:         updates child view frame
    update:         updates canvas drawing
    refresh:        updates child view preview image
*/

extension NoteEditorViewModel {
    static var stub: NoteEditorViewModel {
        let level = NoteModel.NoteLevel(data: NoteModel.NoteData(drawing: PKDrawing(),
                                                                 images: [:]),
                                        children: [:],
                                        preview: .add,
                                        frame: CGRect())
        let note = NoteModel(id: UUID(), title: "Title", root: level)
        return NoteEditorViewModel(note: note, level: level)
    }
}

class NoteEditorTests: XCTestCase {
    func testCreate() {
        let vm = NoteEditorViewModel.stub
        let newNode = NoteModel.NoteLevel.default(preview: .add, frame: CGRect(x: 10, y: 10, width: 100, height: 100))

        vm.process(.create(newNode))

        XCTAssert(vm.sublevels.count == 1)
        XCTAssert(vm.sublevels[newNode.id] != nil)
    }

    func testRemove() {
        let vm = NoteEditorViewModel.stub
        let newNode = NoteModel.NoteLevel.default(preview: .add, frame: CGRect(x: 10, y: 10, width: 100, height: 100))

        vm.process(.create(newNode))

        XCTAssert(vm.sublevels.count == 1)
        XCTAssert(vm.sublevels[newNode.id] != nil)

        vm.process(.remove(newNode))

        XCTAssert(vm.sublevels.isEmpty)
    }
}
