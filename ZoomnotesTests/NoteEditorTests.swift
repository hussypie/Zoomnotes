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

class NoteEditorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    func testCreateSublevel() {
        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
                                         images: [:])

        let descId = UUID()
        let newLevelDescription = NoteLevelDescription(preview: .checkmark,
                                                       frame: CGRect(x: 10, y: 10, width: 200, height: 200),
                                                       id: ID(descId),
                                                       drawing: PKDrawing(),
                                                       sublevels: [],
                                                       images: [])

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note Title",
                                     sublevels: { _ in [] },
                                     drawer: .initd([]),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let originalNumberOfLevelsInDB = mockDB.levels.count

        _ = vm.create(id: newLevelDescription.id,
                      frame: newLevelDescription.frame,
                      preview: newLevelDescription.preview)
            .sink(receiveDone: { XCTAssert(true, "OK")},
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { _ in
                    XCTAssert(vm.nodes.count == 1)
                    XCTAssertNotNil(vm.nodes.first { $0.commander.storeEquals(descId) })

                    XCTAssertEqual(mockDB.levels.count, originalNumberOfLevelsInDB + 1)
                    XCTAssertNotNil(mockDB.levels[newLevelDescription.id])
                    XCTAssertEqual(mockDB.levels[newLevelDescription.id]!.id, newLevelDescription.id)

                    XCTAssertEqual(mockDB.images.count, 0)
                    XCTAssertEqual(mockDB.imageTrash.count, 0)
                    XCTAssertEqual(mockDB.levelTrash.count, 0)
                    XCTAssertEqual(mockDB.imageDrawer.count, 0)
                    XCTAssertEqual(mockDB.levelDrawer.count, 0)
            })
    }

    func testRemove() {
        let sublevel = NoteLevelDescription(preview: .actions,
                                            frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                            id: ID(UUID()),
                                            drawing: PKDrawing(),
                                            sublevels: [],
                                            images: [])

        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [sublevel],
                                        images: [])

        let mockDB = NoteLevelAccessMock(
            levels: [
                sublevel.id: sublevel,
                root.id: root
            ],
            images: [:]
        )

        let sublevelFactory: SublevelFactory = { editor in
            [NoteChildVM(id: UUID(),
                         preview: sublevel.preview,
                         frame: sublevel.frame,
                         commander: NoteLevelCommander(id: sublevel.id,
                                                       editor: editor))]
        }

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Notes",
                                     sublevels: sublevelFactory,
                                     drawer: .initd([]),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let numberOfLevelsInDBBeforeCommand = mockDB.levels.count
        vm.remove(id: sublevel.id)

        XCTAssert(vm.nodes.isEmpty)

        XCTAssertEqual(mockDB.levels.count, numberOfLevelsInDBBeforeCommand - 1)
        XCTAssertEqual(mockDB.imageTrash.count, 0)
        XCTAssertEqual(mockDB.levelTrash.count, 1)
        XCTAssertEqual(mockDB.imageDrawer.count, 0)
        XCTAssertEqual(mockDB.levelDrawer.count, 0)
    }

    func testMove() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let childId = UUID()
        let sublevelFactory: SublevelFactory = { vm in
            [NoteChildVM(id: childId,
                         preview: .checkmark,
                         frame: note.frame,
                         commander: NoteLevelCommander(id: note.id,
                                                       editor: vm))]
        }

        let mockDB = NoteLevelAccessMock(levels: [note.id: note],
                                         images: [:])

        let vm = NoteEditorViewModel(id: ID(UUID()),
                                     title: "Note Title",
                                     sublevels: sublevelFactory,
                                     drawer: .initd([]),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)

        vm.move(id: note.id, to: newFrame)

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertNotNil(vm.nodes.first { $0.id == childId })
        XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)
        XCTAssertEqual(vm.drawer.count, 0)

        XCTAssertEqual(mockDB.levels.count, 1)
        XCTAssertNotNil(mockDB.levels[note.id])
        XCTAssertEqual(mockDB.levels[note.id]!.id, note.id)
        XCTAssertEqual(mockDB.imageTrash.count, 0)
        XCTAssertEqual(mockDB.levelTrash.count, 0)
        XCTAssertEqual(mockDB.imageDrawer.count, 0)
        XCTAssertEqual(mockDB.levelDrawer.count, 0)
    }

    func testResize() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let noteLevelToResize = NoteChildVM(id: note.id,
                                            preview: .checkmark,
                                            frame: note.frame,
                                            commander: NoteLevelCommander())

        let mockDB = NoteLevelAccessMock(levels: [note.id: note],
                                         images: [:])

        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToResize.id: noteLevelToResize],
                                          drawer: [:],
                                          access: mockDB,
                                          onUpdateName: { _ in })

        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)

        vm.process(.resizeLevel(noteLevelToResize, from: noteLevelToResize.frame, to: newFrame))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertNotNil(vm.nodes[noteLevelToResize.id])
        XCTAssertEqual(vm.nodes[noteLevelToResize.id]!.frame, newFrame)
        XCTAssertEqual(vm.drawerContents.count, 0)

        XCTAssertEqual(mockDB.levels.count, 1)
        XCTAssertNotNil(mockDB.levels[noteLevelToResize.id])
        XCTAssertEqual(mockDB.levels[noteLevelToResize.id]!.id, noteLevelToResize.id)
    }

    func testUpdate() {
        let access = NoteLevelAccessMock(levels: [:],
                                         images: [:])
        let vm = NoteEditorViewModel.stub(sublevels: [:],
                                          drawer: [:],
                                          access: access,
                                          onUpdateName: { _ in })
        let newDrawing = PKDrawing()
        vm.process(.update(newDrawing))

        XCTAssert(vm.nodes.isEmpty)
        XCTAssert(vm.drawerContents.isEmpty)
        XCTAssertEqual(vm.drawing, newDrawing)
    }

    func testAddSubImage() {
        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
                                         images: [:])

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: [:],
                                     drawing: root.drawing,
                                     access: mockDB,
                                     drawer: [:],
                                     onUpdateName: { _ in })

        let newImage = NoteChildVM(id: UUID(),
                                   preview: .checkmark,
                                   frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                   commander: NoteImageCommander())

        vm.process(.createImage(newImage))

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertNotNil(vm.nodes[newImage.id])
        XCTAssertEqual(vm.nodes[newImage.id]!.id, newImage.id)
        XCTAssertEqual(vm.nodes[newImage.id]!.frame, newImage.frame)

        XCTAssertEqual(mockDB.images.count, 1)
        XCTAssertNotNil(mockDB.images[newImage.id])
        XCTAssertEqual(mockDB.images[newImage.id]!.frame, newImage.frame)
    }

    func testMoveSubImage() {
        let image = NoteImageDescription(id: UUID(),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [ image ])

        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
                                         images: [image.id: image])

        let imageVM = NoteChildVM(id: image.id,
                                  preview: image.preview,
                                  frame: image.frame,
                                  commander: NoteImageCommander())

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: [imageVM.id: imageVM],
                                     drawing: root.drawing,
                                     access: mockDB,
                                     drawer: [:],
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
        vm.process(.moveImage(imageVM,
                              from: imageVM.frame,
                              to: newFrame))

        XCTAssertNotNil(vm.nodes[imageVM.id])
        XCTAssertEqual(vm.nodes[imageVM.id]!.frame, newFrame)

        XCTAssertNotNil(mockDB.images[image.id])
        XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)
    }

    func testResizeSubImage() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [ image ])

        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
                                         images: [image.id: image])

        let imageVM = NoteChildVM(id: image.id,
                                  preview: image.preview,
                                  frame: image.frame,
                                  commander: NoteImageCommander(id: image.id))

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: [imageVM.id: imageVM],
                                     drawing: root.drawing,
                                     access: mockDB,
                                     drawer: [:],
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
        vm.process(.resizeImage(imageVM,
                                from: imageVM.frame,
                                to: newFrame))

        XCTAssertNotNil(vm.nodes[imageVM.id])
        XCTAssertEqual(vm.nodes[imageVM.id]!.frame, newFrame)

        XCTAssertNotNil(mockDB.images[image.id])
        XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)
    }

    func testRemoveSubImage() {
        let image = NoteImageDescription(id: ID(UUID()),
                                         preview: .checkmark,
                                         drawing: PKDrawing(),
                                         image: .checkmark,
                                         frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: UUID(),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [ image ])

        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
                                         images: [image.id: image])

        let imageVM = NoteChildVM(id: image.id,
                                  preview: image.preview,
                                  frame: image.frame,
                                  commander: NoteImageCommander())

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: [imageVM.id: imageVM],
                                     drawing: root.drawing,
                                     access: mockDB,
                                     drawer: [:],
                                     onUpdateName: { _ in })

        vm.process(.removeImage(imageVM))

        XCTAssertNil(vm.nodes[imageVM.id])
        XCTAssertNil(mockDB.images[image.id])
        XCTAssert(mockDB.levels[root.id]!.images.isEmpty)
    }

    func testMoveToDrawer() {
        let noteLevelToMove = NoteChildVM(id: UUID(),
                                          preview: .checkmark,
                                          frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                          commander: NoteLevelCommander())

        let access = NoteLevelAccessMock(levels: [:],
                                         images: [:])

        let vm = NoteEditorViewModel.stub(sublevels: [noteLevelToMove.id: noteLevelToMove],
                                          drawer: [:],
                                          access: access,
                                          onUpdateName: { _ in })

        let frameWithinDrawer = CGRect(x: 10, y: 10, width: 50, height: 50)
        vm.process(.moveToDrawer(noteLevelToMove, frame: frameWithinDrawer))

        XCTAssert(vm.nodes.isEmpty)
        XCTAssertEqual(vm.drawerContents.count, 1)
        XCTAssertNotNil(vm.drawerContents[noteLevelToMove.id])
        XCTAssertEqual(vm.drawerContents[noteLevelToMove.id]!.id, noteLevelToMove.id)
        XCTAssertEqual(vm.drawerContents[noteLevelToMove.id]!.frame, frameWithinDrawer)
    }

    func testMoveFromDrawer() {
        let noteLevelToMove = NoteChildVM(id: UUID(),
                                          preview: .checkmark,
                                          frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                          commander: NoteLevelCommander())

        let access = NoteLevelAccessMock(levels: [:],
                                         images: [:])

        let vm = NoteEditorViewModel.stub(sublevels: [:],
                                          drawer: [noteLevelToMove.id: noteLevelToMove],
                                          access: access,
                                          onUpdateName: { _ in })

        let frameWithinCanvas = CGRect(x: 10, y: 10, width: 50, height: 50)
        vm.process(.moveFromDrawer(noteLevelToMove, frame: frameWithinCanvas))

        XCTAssert(vm.drawerContents.isEmpty)
        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertNotNil(vm.nodes[noteLevelToMove.id])
        XCTAssertEqual(vm.nodes[noteLevelToMove.id]!.id, noteLevelToMove.id)
        XCTAssertEqual(vm.nodes[noteLevelToMove.id]!.frame, frameWithinCanvas)
    }
}
