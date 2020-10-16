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

//class NoteEditorTests: XCTestCase {
//
//    override func setUp() {
//        super.setUp()
//        self.continueAfterFailure = false
//    }
//
//    func testCreateSublevel() {
//        let root = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [])
//
//        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
//                                         images: [:])
//
//        let vm = NoteEditorViewModel(id: root.id,
//                                     title: "Note",
//                                     sublevels: [:],
//                                     drawing: root.drawing,
//                                     access: mockDB,
//                                     drawer: [:],
//                                     onUpdateName: { _ in })
//
//        let newNode = NoteChildVM(id: UUID(),
//                                  preview: .checkmark,
//                                  frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                  commander: NoteLevelCommander())
//
//        let originalNumberOfLevelsInDB = mockDB.levels.count
//
//        vm.process(.createLevel(newNode))
//
//        XCTAssert(vm.nodes.count == 1)
//        XCTAssertNotNil(vm.nodes[newNode.id])
//        XCTAssert(vm.nodes[newNode.id]!.id == newNode.id)
//        XCTAssert(vm.drawerContents.isEmpty)
//
//        XCTAssertEqual(mockDB.levels.count, originalNumberOfLevelsInDB + 1)
//        XCTAssertNotNil(mockDB.levels[newNode.id])
//        XCTAssertEqual(mockDB.levels[newNode.id]!.id, newNode.id)
//    }
//
//    func testRemove() {
//        let sublevel = NoteLevelDescription(preview: .actions,
//                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
//                                            id: UUID(),
//                                            drawing: PKDrawing(),
//                                            sublevels: [],
//                                            images: [])
//
//        let root = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [sublevel],
//                                        images: [])
//
//        let mockDB = NoteLevelAccessMock(levels: [
//            sublevel.id: sublevel,
//            root.id: root
//        ], images: [:])
//
//        let sublevelVM = NoteChildVM(id: sublevel.id,
//                                     preview: sublevel.preview,
//                                     frame: sublevel.frame,
//                                     commander: NoteLevelCommander())
//
//        let vm = NoteEditorViewModel(id: root.id,
//                                     title: "Notes",
//                                     sublevels: [sublevel.id: sublevelVM],
//                                     drawing: root.drawing,
//                                     access: mockDB,
//                                     drawer: [:],
//                                     onUpdateName: { _ in })
//
//        let numberOfLevelsInDBBeforeCommand = mockDB.levels.count
//        vm.process(.removeLevel(sublevelVM))
//
//        XCTAssert(vm.nodes.isEmpty)
//        XCTAssert(vm.drawerContents.isEmpty)
//
//        XCTAssertEqual(mockDB.levels.count, numberOfLevelsInDBBeforeCommand - 1)
//    }
//
//    func testMove() {
//        let note = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [])
//
//        let noteLevelToMove = NoteChildVM(id: note.id,
//                                            preview: .checkmark,
//                                            frame: note.frame,
//                                            commander: NoteLevelCommander())
//
//        let mockDB = NoteLevelAccessMock(levels: [note.id: note],
//                                         images: [:])
//        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToMove.id: noteLevelToMove],
//                                          drawer: [:],
//                                          access: mockDB,
//                                          onUpdateName: { _ in })
//
//        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)
//
//        vm.process(.moveLevel(noteLevelToMove, from: noteLevelToMove.frame, to: newFrame))
//
//        XCTAssertEqual(vm.nodes.count, 1)
//        XCTAssertNotNil(vm.nodes[noteLevelToMove.id])
//        XCTAssertEqual(vm.nodes[noteLevelToMove.id]!.frame, newFrame)
//        XCTAssertEqual(vm.drawerContents.count, 0)
//
//        XCTAssertEqual(mockDB.levels.count, 1)
//        XCTAssertNotNil(mockDB.levels[note.id])
//        XCTAssertEqual(mockDB.levels[note.id]!.id, note.id)
//    }
//
//    func testResize() {
//        let note = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [])
//
//        let noteLevelToResize = NoteChildVM(id: note.id,
//                                            preview: .checkmark,
//                                            frame: note.frame,
//                                            commander: NoteLevelCommander())
//
//        let mockDB = NoteLevelAccessMock(levels: [note.id: note],
//                                         images: [:])
//        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToResize.id: noteLevelToResize],
//                                          drawer: [:],
//                                          access: mockDB,
//                                          onUpdateName: { _ in })
//
//        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)
//
//        vm.process(.resizeLevel(noteLevelToResize, from: noteLevelToResize.frame, to: newFrame))
//
//        XCTAssertEqual(vm.nodes.count, 1)
//        XCTAssertNotNil(vm.nodes[noteLevelToResize.id])
//        XCTAssertEqual(vm.nodes[noteLevelToResize.id]!.frame, newFrame)
//        XCTAssertEqual(vm.drawerContents.count, 0)
//
//        XCTAssertEqual(mockDB.levels.count, 1)
//        XCTAssertNotNil(mockDB.levels[noteLevelToResize.id])
//        XCTAssertEqual(mockDB.levels[noteLevelToResize.id]!.id, noteLevelToResize.id)
//    }
//
//    func testUpdate() {
//        let access = NoteLevelAccessMock(levels: [:],
//                                         images: [:])
//        let vm = NoteEditorViewModel.stub(sublevels: [:],
//                                          drawer: [:],
//                                          access: access,
//                                          onUpdateName: { _ in })
//        let newDrawing = PKDrawing()
//        vm.process(.update(newDrawing))
//
//        XCTAssert(vm.nodes.isEmpty)
//        XCTAssert(vm.drawerContents.isEmpty)
//        XCTAssertEqual(vm.drawing, newDrawing)
//    }
//
//    func testMoveToDrawer() {
//        let noteLevelToMove = NoteChildVM(id: UUID(),
//                                            preview: .checkmark,
//                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
//                                            commander: NoteLevelCommander())
//
//        let access = NoteLevelAccessMock(levels: [:],
//                                         images: [:])
//
//        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToMove.id: noteLevelToMove],
//                                          drawer: [:],
//                                          access: access,
//                                          onUpdateName: { _ in })
//
//        let frameWithinDrawer = CGRect(x: 10, y: 10, width: 50, height: 50)
//        vm.process(.moveToDrawer(noteLevelToMove, frame: frameWithinDrawer))
//
//        XCTAssert(vm.nodes.isEmpty)
//        XCTAssertEqual(vm.drawerContents.count, 1)
//        XCTAssertNotNil(vm.drawerContents[noteLevelToMove.id])
//        XCTAssertEqual(vm.drawerContents[noteLevelToMove.id]!.id, noteLevelToMove.id)
//        XCTAssertEqual(vm.drawerContents[noteLevelToMove.id]!.frame, frameWithinDrawer)
//    }
//
//    func testMoveFromDrawer() {
//        let noteLevelToMove = NoteChildVM(id: UUID(),
//                                            preview: .checkmark,
//                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
//                                            commander: NoteLevelCommander())
//
//        let access = NoteLevelAccessMock(levels: [:],
//                                         images: [:])
//
//        let vm = NoteEditorViewModel.stub(sublevels: [:],
//                                          drawer: [noteLevelToMove.id: noteLevelToMove],
//                                          access: access,
//                                          onUpdateName: { _ in })
//
//        let frameWithinCanvas = CGRect(x: 10, y: 10, width: 50, height: 50)
//        vm.process(.moveFromDrawer(noteLevelToMove, frame: frameWithinCanvas))
//
//        XCTAssert(vm.drawerContents.isEmpty)
//        XCTAssertEqual(vm.nodes.count, 1)
//        XCTAssertNotNil(vm.nodes[noteLevelToMove.id])
//        XCTAssertEqual(vm.nodes[noteLevelToMove.id]!.id, noteLevelToMove.id)
//        XCTAssertEqual(vm.nodes[noteLevelToMove.id]!.frame, frameWithinCanvas)
//    }
//
//    func testAddSubImage() {
//        let root = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [])
//
//        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
//                                         images: [:])
//
//        let vm = NoteEditorViewModel(id: root.id,
//                                     title: "Note",
//                                     sublevels: [:],
//                                     drawing: root.drawing,
//                                     access: mockDB,
//                                     drawer: [:],
//                                     onUpdateName: { _ in })
//
//        let newImage = NoteChildVM(id: UUID(),
//                                   preview: .checkmark,
//                                   frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                   commander: NoteImageCommander())
//
//        vm.process(.createImage(newImage))
//
//        XCTAssertEqual(vm.nodes.count, 1)
//        XCTAssertNotNil(vm.nodes[newImage.id])
//        XCTAssertEqual(vm.nodes[newImage.id]!.id, newImage.id)
//        XCTAssertEqual(vm.nodes[newImage.id]!.frame, newImage.frame)
//
//        XCTAssertEqual(mockDB.images.count, 1)
//        XCTAssertNotNil(mockDB.images[newImage.id])
//        XCTAssertEqual(mockDB.images[newImage.id]!.frame, newImage.frame)
//    }
//
//    func testMoveSubImage() {
//        let image = NoteImageDescription(id: UUID(),
//                                         preview: .checkmark,
//                                         drawing: PKDrawing(),
//                                         image: .checkmark,
//                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//
//        let root = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [ image ])
//
//        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
//                                         images: [image.id: image])
//
//        let imageVM = NoteChildVM(id: image.id,
//                                  preview: image.preview,
//                                  frame: image.frame,
//                                  commander: NoteImageCommander())
//
//        let vm = NoteEditorViewModel(id: root.id,
//                                     title: "Note",
//                                     sublevels: [imageVM.id: imageVM],
//                                     drawing: root.drawing,
//                                     access: mockDB,
//                                     drawer: [:],
//                                     onUpdateName: { _ in })
//
//        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
//        vm.process(.moveImage(imageVM,
//                              from: imageVM.frame,
//                              to: newFrame))
//
//        XCTAssertNotNil(vm.nodes[imageVM.id])
//        XCTAssertEqual(vm.nodes[imageVM.id]!.frame, newFrame)
//
//        XCTAssertNotNil(mockDB.images[image.id])
//        XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)
//    }
//
//    func testResizeSubImage() {
//        let image = NoteImageDescription(id: UUID(),
//                                         preview: .checkmark,
//                                         drawing: PKDrawing(),
//                                         image: .checkmark,
//                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//
//        let root = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [ image ])
//
//        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
//                                         images: [image.id: image])
//
//        let imageVM = NoteChildVM(id: image.id,
//                                  preview: image.preview,
//                                  frame: image.frame,
//                                  commander: NoteImageCommander())
//
//        let vm = NoteEditorViewModel(id: root.id,
//                                     title: "Note",
//                                     sublevels: [imageVM.id: imageVM],
//                                     drawing: root.drawing,
//                                     access: mockDB,
//                                     drawer: [:],
//                                     onUpdateName: { _ in })
//
//        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
//        vm.process(.resizeImage(imageVM,
//                              from: imageVM.frame,
//                              to: newFrame))
//
//        XCTAssertNotNil(vm.nodes[imageVM.id])
//        XCTAssertEqual(vm.nodes[imageVM.id]!.frame, newFrame)
//
//        XCTAssertNotNil(mockDB.images[image.id])
//        XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)
//    }
//
//    func testRemoveSubImage() {
//        let image = NoteImageDescription(id: UUID(),
//                                         preview: .checkmark,
//                                         drawing: PKDrawing(),
//                                         image: .checkmark,
//                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//
//        let root = NoteLevelDescription(preview: .checkmark,
//                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
//                                        id: UUID(),
//                                        drawing: PKDrawing(),
//                                        sublevels: [],
//                                        images: [ image ])
//
//        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
//                                         images: [image.id: image])
//
//        let imageVM = NoteChildVM(id: image.id,
//                                  preview: image.preview,
//                                  frame: image.frame,
//                                  commander: NoteImageCommander())
//
//        let vm = NoteEditorViewModel(id: root.id,
//                                     title: "Note",
//                                     sublevels: [imageVM.id: imageVM],
//                                     drawing: root.drawing,
//                                     access: mockDB,
//                                     drawer: [:],
//                                     onUpdateName: { _ in })
//
//        vm.process(.removeImage(imageVM))
//
//        XCTAssertNil(vm.nodes[imageVM.id])
//        XCTAssertNil(mockDB.images[image.id])
//        XCTAssert(mockDB.levels[root.id]!.images.isEmpty)
//    }
//}
