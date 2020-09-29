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
    refresh:        updates view preview image
*/

class NoteEditorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    func testCreate() {
        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [])

        let mockDB = NoteLevelAccessMock(db: [root.id: root])

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: [:],
                                     drawing: root.drawing,
                                     access: mockDB,
                                     drawer: [:],
                                     onUpdateName: { _ in })

        let newNode = NoteLevelVM(id: UUID(),
                                  preview: .checkmark,
                                  frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let originalNumberOfLevelsInDB = mockDB.db.count

        vm.process(.create(newNode))

        XCTAssert(vm.sublevels.count == 1)
        XCTAssertNotNil(vm.sublevels[newNode.id])
        XCTAssert(vm.sublevels[newNode.id]!.id == newNode.id)
        XCTAssert(vm.drawerContents.isEmpty)

        XCTAssertEqual(mockDB.db.count, originalNumberOfLevelsInDB + 1)
        XCTAssertNotNil(mockDB.db[newNode.id])
        XCTAssertEqual(mockDB.db[newNode.id]!.id, newNode.id)
    }

    func testRemove() {
        let sublevel = NoteLevelDescription(preview: .actions,
                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                            id: UUID(),
                                            drawing: PKDrawing(),
                                            sublevels: [])

        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [sublevel])

        let mockDB = NoteLevelAccessMock(db: [
            sublevel.id: sublevel,
            root.id: root
        ])

        let sublevelVM = NoteLevelVM(id: sublevel.id,
                                     preview: sublevel.preview,
                                     frame: sublevel.frame)

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Notes",
                                     sublevels: [sublevel.id: sublevelVM],
                                     drawing: root.drawing,
                                     access: mockDB,
                                     drawer: [:],
                                     onUpdateName: { _ in })

        let numberOfLevelsInDBBeforeCommand = mockDB.db.count
        vm.process(.remove(sublevelVM))

        XCTAssert(vm.sublevels.isEmpty)
        XCTAssert(vm.drawerContents.isEmpty)

        XCTAssertEqual(mockDB.db.count, numberOfLevelsInDBBeforeCommand - 1)
    }

    func testMove() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [])

        let noteLevelToMove = NoteLevelVM(id: note.id,
                                            preview: .checkmark,
                                            frame: note.frame)

        let mockDB = NoteLevelAccessMock(db: [note.id: note])
        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToMove.id: noteLevelToMove],
                                          drawer: [:],
                                          access: mockDB,
                                          onUpdateName: { _ in })

        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)

        vm.process(.move(noteLevelToMove, from: noteLevelToMove.frame, to: newFrame))

        XCTAssertEqual(vm.sublevels.count, 1)
        XCTAssertNotNil(vm.sublevels[noteLevelToMove.id])
        XCTAssertEqual(vm.sublevels[noteLevelToMove.id]!.frame, newFrame)
        XCTAssertEqual(vm.drawerContents.count, 0)

        XCTAssertEqual(mockDB.db.count, 1)
        XCTAssertNotNil(mockDB.db[note.id])
        XCTAssertEqual(mockDB.db[note.id]!.id, note.id)
    }

    func testResize() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [])

        let noteLevelToResize = NoteLevelVM(id: note.id,
                                            preview: .checkmark,
                                            frame: note.frame)

        let mockDB = NoteLevelAccessMock(db: [note.id: note])
        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToResize.id: noteLevelToResize],
                                          drawer: [:],
                                          access: mockDB,
                                          onUpdateName: { _ in })

        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)

        vm.process(.resize(noteLevelToResize, from: noteLevelToResize.frame, to: newFrame))

        XCTAssertEqual(vm.sublevels.count, 1)
        XCTAssertNotNil(vm.sublevels[noteLevelToResize.id])
        XCTAssertEqual(vm.sublevels[noteLevelToResize.id]!.frame, newFrame)
        XCTAssertEqual(vm.drawerContents.count, 0)

        XCTAssertEqual(mockDB.db.count, 1)
        XCTAssertNotNil(mockDB.db[noteLevelToResize.id])
        XCTAssertEqual(mockDB.db[noteLevelToResize.id]!.id, noteLevelToResize.id)
    }

    func testUpdate() {
        let vm = NoteEditorViewModel.stub(sublevels: [:],
                                          drawer: [:],
                                          access: NoteLevelAccessMock(db: [:]),
                                          onUpdateName: { _ in })
        let newDrawing = PKDrawing()
        vm.process(.update(newDrawing))

        XCTAssert(vm.sublevels.isEmpty)
        XCTAssert(vm.drawerContents.isEmpty)
        XCTAssertEqual(vm.drawing, newDrawing)
    }

    func testMoveToDrawer() {
        let noteLevelToMove = NoteLevelVM(id: UUID(),
                                            preview: .checkmark,
                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200))

        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToMove.id: noteLevelToMove],
                                          drawer: [:],
                                          access: NoteLevelAccessMock(db: [:]),
                                          onUpdateName: { _ in })

        let frameWithinDrawer = CGRect(x: 10, y: 10, width: 50, height: 50)
        vm.process(.moveToDrawer(noteLevelToMove, frame: frameWithinDrawer))

        XCTAssert(vm.sublevels.isEmpty)
        XCTAssertEqual(vm.drawerContents.count, 1)
        XCTAssertNotNil(vm.drawerContents[noteLevelToMove.id])
        XCTAssertEqual(vm.drawerContents[noteLevelToMove.id]!.id, noteLevelToMove.id)
        XCTAssertEqual(vm.drawerContents[noteLevelToMove.id]!.frame, frameWithinDrawer)
    }

    func testMoveFromDrawer() {
        let noteLevelToMove = NoteLevelVM(id: UUID(),
                                            preview: .checkmark,
                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200))

        let vm = NoteEditorViewModel.stub(sublevels: [:],
                                          drawer: [noteLevelToMove.id: noteLevelToMove],
                                          access: NoteLevelAccessMock(db: [:]),
                                          onUpdateName: { _ in })

        let frameWithinCanvas = CGRect(x: 10, y: 10, width: 50, height: 50)
        vm.process(.moveFromDrawer(noteLevelToMove, frame: frameWithinCanvas))

        XCTAssert(vm.drawerContents.isEmpty)
        XCTAssertEqual(vm.sublevels.count, 1)
        XCTAssertNotNil(vm.sublevels[noteLevelToMove.id])
        XCTAssertEqual(vm.sublevels[noteLevelToMove.id]!.id, noteLevelToMove.id)
        XCTAssertEqual(vm.sublevels[noteLevelToMove.id]!.frame, frameWithinCanvas)
    }
}
