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
                                     sublevels: [],
                                     drawer: DrawerVM(nodes: []),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let originalNumberOfLevelsInDB = mockDB.levels.count

        let newId: NoteChildStore = .level(newLevelDescription.id)
        _ = vm.create(id: newId,
                      frame: newLevelDescription.frame,
                      preview: newLevelDescription.preview)
            .sink(receiveDone: { XCTAssert(true, "OK")},
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { _ in
                    XCTAssert(vm.nodes.count == 1)
                    XCTAssertNotNil(vm.nodes.first { $0.store == newId })

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

        let sublevels = [
            NoteChildVM(id: UUID(),
                        preview: sublevel.preview,
                        frame: sublevel.frame,
                        store: .level(sublevel.id))
        ]

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Notes",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let numberOfLevelsInDBBeforeCommand = mockDB.levels.count
        _ = vm.remove(child: sublevels.first!)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssert(vm.nodes.isEmpty)

                    XCTAssertEqual(mockDB.levels.count, numberOfLevelsInDBBeforeCommand - 1)

                    XCTAssert(mockDB.imageTrash.isEmpty)
                    XCTAssert(mockDB.imageDrawer.isEmpty)
                    XCTAssert(mockDB.levelDrawer.isEmpty)
                    XCTAssertEqual(mockDB.levelTrash.count, 1)
            })
    }

    func testMove() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let childId = UUID()
        let sublevels = [NoteChildVM(id: childId,
                                     preview: .checkmark,
                                     frame: note.frame,
                                     store: .level(note.id))]

        let mockDB = NoteLevelAccessMock(levels: [note.id: note],
                                         images: [:])

        let vm = NoteEditorViewModel(id: ID(UUID()),
                                     title: "Note Title",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)

        _ = vm.move(child: sublevels.first!, to: newFrame)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertNotNil(vm.nodes.first { $0.id == childId })
                    XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)
                    XCTAssertEqual(vm.drawer.nodes.count, 0)

                    XCTAssertEqual(mockDB.levels.count, 1)
                    XCTAssertNotNil(mockDB.levels[note.id])
                    XCTAssertEqual(mockDB.levels[note.id]!.id, note.id)
                    XCTAssertEqual(mockDB.imageTrash.count, 0)
                    XCTAssertEqual(mockDB.levelTrash.count, 0)
                    XCTAssertEqual(mockDB.imageDrawer.count, 0)
                    XCTAssertEqual(mockDB.levelDrawer.count, 0)
            })
    }

    func testResize() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let childId = UUID()
        let sublevels = [
            NoteChildVM(id: childId,
                        preview: .checkmark,
                        frame: note.frame,
                        store: .level(note.id))
        ]

        let mockDB = NoteLevelAccessMock(levels: [note.id: note],
                                         images: [:])

        let vm = NoteEditorViewModel(id: ID(UUID()),
                                     title: "Note Title",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 10, y: 10, width: 300, height: 300)

        _ = vm.resize(child: sublevels.first!, to: newFrame)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
                    XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)
                    XCTAssertEqual(vm.drawer.nodes.count, 0)

                    XCTAssertEqual(mockDB.levels.count, 1)
                    XCTAssertNotNil(mockDB.levels[note.id])
            })
    }

    func testUpdate() {
        let access = NoteLevelAccessMock(levels: [:],
                                         images: [:])

        let vm = NoteEditorViewModel(id: ID(UUID()),
                                     title: "Note Title",
                                     sublevels: [],
                                     drawer: DrawerVM(nodes: []),
                                     drawing: PKDrawing(),
                                     access: access,
                                     onUpdateName: { _ in })

        let newDrawing = PKDrawing()
        _ = vm.update(drawing: newDrawing)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssert(vm.nodes.isEmpty)
                    XCTAssert(vm.drawer.nodes.isEmpty)
                    XCTAssertEqual(vm.drawing, newDrawing)
            })
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
                                     sublevels: [],
                                     drawer: DrawerVM(nodes: []),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let imageId: NoteImageID = ID(UUID())
        let imageFrame = CGRect(x: 10, y: 10, width: 100, height: 100)
        _ = vm
            .create(id: .image(imageId), frame: CGRect(x: 10, y: 10, width: 100, height: 100), preview: .checkmark)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: { (cvm: NoteChildVM) in
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertEqual(cvm.frame, imageFrame)
                    XCTAssert(cvm.store == .image(imageId))

                    XCTAssertEqual(mockDB.images.count, 1)
                    XCTAssertNotNil(mockDB.images[imageId])
                    XCTAssertEqual(mockDB.images[imageId]!.frame, imageFrame)
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
        let sublevels = [
            NoteChildVM(id: childId,
                        preview: image.preview,
                        frame: image.frame,
                        store: .image(image.id))
        ]

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
        _ = vm.move(child: sublevels.first!, to: newFrame)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
                    XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)

                    XCTAssertNotNil(mockDB.images[image.id])
                    XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)

                    self.assertDrawerTrashEmpty(db: mockDB)
            })
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
        let sublevels = [
            NoteChildVM(id: childId,
                        preview: image.preview,
                        frame: image.frame,
                        store: .image(image.id))
        ]

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let newFrame = CGRect(x: 100, y: 100, width: 100, height: 100)
        _ = vm.resize(child: sublevels.first!, to: newFrame)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
                    XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, newFrame)

                    XCTAssertNotNil(mockDB.images[image.id])
                    XCTAssertEqual(mockDB.images[image.id]!.frame, newFrame)

                    self.assertDrawerTrashEmpty(db: mockDB)
            })
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
        let sublevels = [
            NoteChildVM(id: childId,
                        preview: image.preview,
                        frame: image.frame,
                        store: .image(image.id))
        ]

        let vm = NoteEditorViewModel(id: root.id,
                                     title: "Note",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: root.drawing,
                                     access: mockDB,
                                     onUpdateName: { _ in })

        _ = vm.remove(child: sublevels.first!)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssertNil(vm.nodes.first(where: { $0.id == childId }))
                    XCTAssertNil(mockDB.images[image.id])
                    XCTAssertEqual(mockDB.imageTrash.count, 1)
                    XCTAssertNotNil(mockDB.imageTrash[image.id])
                    XCTAssert(mockDB.levels[root.id]!.images.isEmpty)

                    XCTAssert(mockDB.levelTrash.isEmpty)
                    XCTAssert(mockDB.imageDrawer.isEmpty)
                    XCTAssert(mockDB.levelDrawer.isEmpty)
                    XCTAssertEqual(mockDB.imageTrash.count, 1)
            })
    }

    // swiftlint:disable:next function_body_length
    func testMoveToDrawer() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let parent = NoteLevelDescription(preview: .actions,
                                          frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                          id: ID(UUID()),
                                          drawing: PKDrawing(),
                                          sublevels: [ note ],
                                          images: [])

        let childId = UUID()
        let sublevels = [NoteChildVM(id: childId,
                                     preview: .checkmark,
                                     frame: note.frame,
                                     store: .level(note.id))]

        let mockDB = NoteLevelAccessMock(
            levels: [
                note.id: note,
                parent.id: parent
            ],
            images: [:]
        )

        let vm = NoteEditorViewModel(id: parent.id,
                                     title: "Note Title",
                                     sublevels: sublevels,
                                     drawer: DrawerVM(nodes: []),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let frameWithinDrawer = CGRect(x: 10, y: 10, width: 50, height: 50)
        _ = vm.moveToDrawer(child: sublevels.first!, frame: frameWithinDrawer)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssert(vm.nodes.isEmpty)
                    XCTAssertEqual(vm.drawer.nodes.count, 1)
                    XCTAssertNotNil(vm.drawer.nodes.first(where: { $0.id == childId }))
                    XCTAssertEqual(vm.drawer.nodes.first(where: { $0.id == childId })!.frame, frameWithinDrawer)

                    XCTAssertEqual(mockDB.levelDrawer.count, 1)
                    XCTAssertNotNil(mockDB.levelDrawer[note.id])
                    XCTAssert(mockDB.imageDrawer.isEmpty)
                    XCTAssert(mockDB.levelTrash.isEmpty)
                    XCTAssertEqual(mockDB.levels.count, 1)
            })
    }

    // swiftlint:disable:next function_body_length
    func testMoveFromDrawer() {
        let note = NoteLevelDescription(preview: .checkmark,
                                        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                        id: ID(UUID()),
                                        drawing: PKDrawing(),
                                        sublevels: [],
                                        images: [])

        let parent = NoteLevelDescription(preview: .actions,
                                          frame: CGRect(x: 0, y: 0, width: 200, height: 200),
                                          id: ID(UUID()),
                                          drawing: PKDrawing(),
                                          sublevels: [ ],
                                          images: [])

        let childId = UUID()
        let drawer = [
            NoteChildVM(id: childId,
                        preview: .checkmark,
                        frame: note.frame,
                        store: .level(note.id))
        ]

        let mockDB = NoteLevelAccessMock(
            levels: [parent.id: parent],
            images: [:]
        )
            .drawer(levels: [note.id: note],
                    images: [:])

        let vm = NoteEditorViewModel(id: parent.id,
                                     title: "Note Title",
                                     sublevels: [],
                                     drawer: DrawerVM(nodes: drawer),
                                     drawing: PKDrawing(),
                                     access: mockDB,
                                     onUpdateName: { _ in })

        let frameWithinCanvas = CGRect(x: 10, y: 10, width: 50, height: 50)
        _ = vm.moveFromDrawer(child: drawer.first!, frame: frameWithinCanvas)
            .sink(receiveDone: { },
                  receiveError: { XCTFail($0.localizedDescription) },
                  receiveValue: {
                    XCTAssert(vm.drawer.nodes.isEmpty)
                    XCTAssertEqual(vm.nodes.count, 1)
                    XCTAssertNotNil(vm.nodes.first(where: { $0.id == childId }))
                    XCTAssertEqual(vm.nodes.first(where: { $0.id == childId })!.frame, frameWithinCanvas)

                    XCTAssertNotNil(mockDB.levels[note.id])

                    self.assertDrawerTrashEmpty(db: mockDB)
            })
    }
}
