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

// swiftlint:disable:next type_body_length
class NoteEditorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    private func assertDrawerTrashEmpty(db mockDB: NoteLevelAccessMock) {
        XCTAssertEqual(mockDB.imageTrash.count, 0)
        XCTAssertEqual(mockDB.levelTrash.count, 0)
        XCTAssertEqual(mockDB.imageDrawer.count, 0)
        XCTAssertEqual(mockDB.levelDrawer.count, 0)
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

                    self.assertDrawerTrashEmpty(db: mockDB)
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
        assertDrawerTrashEmpty(db: mockDB)
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

        let childId = UUID()
        let sublevelFactory: SublevelFactory = { vm in
            [
                NoteChildVM(id: childId,
                            preview: .checkmark,
                            frame: note.frame,
                            commander: NoteLevelCommander(id: note.id,
                                                          editor: vm))
            ]
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

        vm.resize(id: note.id, to: newFrame)

        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
        XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)
        XCTAssertEqual(vm.drawer.count, 0)

        XCTAssertEqual(mockDB.levels.count, 1)
        XCTAssertNotNil(mockDB.levels[note.id])
    }

    func testUpdate() {
        let access = NoteLevelAccessMock(levels: [:],
                                         images: [:])

        let vm = NoteEditorViewModel(id: ID(UUID()),
                                     title: "Note Title",
                                     sublevels: { _ in [] },
                                     drawer: .initd([]),
                                     drawing: PKDrawing(),
                                     access: access,
                                     onUpdateName: { _ in })

        let newDrawing = PKDrawing()
        vm.update(drawing: newDrawing)

        XCTAssert(vm.nodes.isEmpty)
        XCTAssert(vm.drawer.isEmpty)
        XCTAssertEqual(vm.drawing, newDrawing)
    }

    func testAddSubImage() {
        let root = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let mockDB = NoteLevelAccessMock(levels: [root.id: root],
                                         images: [:])

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: { _ in [] },
                                     drawer: .initd([]),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let imageId = UUID()
        let imageTagId: NoteImageID = ID(UUID())
        let imageFrame = CGRect(x: 10, y: 10, width: 100, height: 100)
        _ = vm
            .create(id: imageTagId, frame: CGRect(x: 10, y: 10, width: 100, height: 100), preview: .checkmark)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { (cvm: NoteChildVM) in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(cvm.frame, imageFrame)
                    XCTAssert(cvm.commander.storeEquals(imageId))

                    XCTAssertEqual(mockDB.images.count, 1)
                    XCTAssertNotNil(mockDB.images[imageTagId])
                    XCTAssertEqual(mockDB.images[imageTagId]!.frame, imageFrame)
            })
    }

    func testMoveSubImage() {
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

        let childId = UUID()
        let sublevelFactory: SublevelFactory = { vm in
            [
                NoteChildVM(id: childId,
                            preview: image.preview,
                            frame: image.frame,
                            commander: NoteImageCommander(id: image.id,
                                                          editor: vm))
            ]
        }

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: sublevelFactory,
                                     drawer: .initd([]),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
        vm.move(id: image.id, to: newFrame)

        XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
        XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)

        XCTAssertNotNil(mockDB.images[image.id])
        XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)

        self.assertDrawerTrashEmpty(db: mockDB)
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

        let childId = UUID()
        let sublevelFactory: SublevelFactory = { vm in
            [
                NoteChildVM(id: childId,
                            preview: image.preview,
                            frame: image.frame,
                            commander: NoteImageCommander(id: image.id,
                                                          editor: vm))
            ]
        }

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: sublevelFactory,
                                     drawer: .initd([]),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
        vm.resize(id: image.id, to: newFrame)

        XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
        XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)

        XCTAssertNotNil(mockDB.images[image.id])
        XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)

        self.assertDrawerTrashEmpty(db: mockDB)
    }

    func testRemoveSubImage() {
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
        let childId = UUID()
        let sublevelFactory: SublevelFactory = { vm in
            [
                NoteChildVM(id: childId,
                            preview: image.preview,
                            frame: image.frame,
                            commander: NoteImageCommander(id: image.id,
                                                          editor: vm))
            ]
        }

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: sublevelFactory,
                                     drawer: .initd([]),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        vm.remove(id: image.id)

        XCTAssertNil(vm.nodes.first(where: { $0.id == childId}))
        XCTAssertNil(mockDB.images[image.id])
        XCTAssertEqual(mockDB.imageTrash.count, 1)
        XCTAssertNotNil(mockDB.imageTrash[image.id])
        XCTAssert(mockDB.levels[root.id]!.images.isEmpty)

        XCTAssert(mockDB.levelTrash.isEmpty)
        XCTAssert(mockDB.imageDrawer.isEmpty)
        XCTAssert(mockDB.levelDrawer.isEmpty)
    }

    func testMoveToDrawer() {
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

        let frameWithinDrawer = CGRect(x: 10, y: 10, width: 50, height: 50)
        vm.moveToDrawer(id: note.id, frame: frameWithinDrawer)

        XCTAssert(vm.nodes.isEmpty)
        XCTAssertEqual(vm.drawer.count, 1)
        XCTAssertNotNil(vm.drawer.first(where: { $0.id == childId }))
        XCTAssertEqual(vm.drawer.first(where: { $0.id == childId })!.frame, frameWithinDrawer)

        XCTAssertEqual(mockDB.levelDrawer.count, 1)
        XCTAssertNotNil(mockDB.levelDrawer[note.id])
        XCTAssert(mockDB.imageDrawer.isEmpty)
        XCTAssert(mockDB.levelTrash.isEmpty)
        XCTAssert(mockDB.levelDrawer.isEmpty)
    }

    func testMoveFromDrawer() {
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
                                     sublevels: { _ in [] },
                                     drawer: .uninitd(sublevelFactory),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })


        let frameWithinCanvas = CGRect(x: 10, y: 10, width: 50, height: 50)
        vm.moveFromDrawer(id: note.id, frame: frameWithinCanvas)

        XCTAssert(vm.drawer.isEmpty)
        XCTAssertEqual(vm.nodes.count, 1)
        XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
        XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, frameWithinCanvas)

        XCTAssertNotNil(mockDB.levels[note.id])

        self.assertDrawerTrashEmpty(db: mockDB)
    }
}
