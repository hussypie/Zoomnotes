//
//  FileBrowserDBAccessTests.swift
//  ZoomnotesTests
//
//  Created by Berci on 2020. 09. 14..
//  Copyright © 2020. Berci. All rights reserved.
//

import XCTest
import CoreData
import Combine

@testable import Zoomnotes

class FileBrowserDBAccessTests: XCTestCase {
    let moc = NSPersistentContainer.inMemory(name: "Zoomnotes").viewContext

    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    enum AccessType {
        case read
        case write
    }

    func testCreateFile() {
        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Root",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc)).stub(root: root)

        let rootLevel = NoteLevelDescription.stub(parent: nil)
        let fileToBeCreated =
            DocumentStoreDescription(id: ID(UUID()),
                                     lastModified: Date(),
                                     name: "New file",
                                     thumbnail: .checkmark,
                                     root: rootLevel)

        let appendAction = access.append(document: fileToBeCreated, to: root.id)
        let noteLevelAccess = NoteLevelAccessImpl(access: DBAccess(moc: moc))

        let _ = appendAction
            .flatMap({ access.children(of: root.id) })
            .flatMap { result -> AnyPublisher<NoteLevelDescription?, Error> in
                XCTAssertEqual(result.count, 1)
                switch result.first! {
                case .file(let file):
                    XCTAssertEqual(fileToBeCreated.id, file.store)
                    XCTAssertEqual(file.name, fileToBeCreated.name)
                    XCTAssertEqual(file.lastModified, fileToBeCreated.lastModified)
                default:
                    XCTFail("Created file shoud be file")
                }
                return noteLevelAccess.read(level: rootLevel.id).eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { error in XCTFail("\(error)")},
              receiveValue: { rootLevel2 in
                XCTAssertNotNil(rootLevel2)
                XCTAssertEqual(rootLevel2!.id, rootLevel.id)
        })

    }

    func testUpdateFileLastModified() {
        let fileToBeUpdated = DocumentStoreDescription.stub
        let root = DirectoryStoreDescription.stub(documents: [
            DocumentStoreDescription.stub,
            fileToBeUpdated,
            DocumentStoreDescription.stub
        ], directories: [])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc)).stub(root: root)

        let newDate = Date().advanced(by: 24*68*60)

        _ = access.updateLastModified(of: fileToBeUpdated.id, with: newDate)
            .flatMap { _ in access.children(of: root.id) }
            .sink(receiveCompletion: { error in XCTFail("\(error)")},
                  receiveValue: { children in
                    XCTAssertEqual(children.count, 3)
                    let updatedFile = children.first { $0.id == fileToBeUpdated.id }!
                    XCTAssertEqual(updatedFile.date, newDate)
            })
    }

    func testUpdateFileName() {
        let fileToBeUpdated = DocumentStoreDescription.stub
        let root = DirectoryStoreDescription.stub(documents: [
            DocumentStoreDescription.stub,
            fileToBeUpdated,
            DocumentStoreDescription.stub
        ], directories: [])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc)).stub(root: root)

        let newName = "This name is surely better than the prevoius one"
        let _ =
        access.updateName(of: fileToBeUpdated.id, to: newName)
            .flatMap { _ in access.children(of: root.id) }
            .sink(receiveCompletion: { error in XCTFail("\(error)")},
                  receiveValue: { children in
                    XCTAssertEqual(children.count, 3)
                    let updatedFile = children.first { $0.id == fileToBeUpdated.id }!
                    XCTAssertEqual(updatedFile.name, newName)
            })
    }

    func testUpdateDirectoryName() {
        let directoryToBeUpdated = DirectoryStoreDescription.stub
        let access = DirectoryAccessImpl(access: DBAccess(moc: moc))
            .stub(root: DirectoryStoreDescription.stub(documents: [],
                                                       directories: [
                                                        DirectoryStoreDescription.stub,
                                                        directoryToBeUpdated,
                                                        DirectoryStoreDescription.stub
            ]))

        let newName = "This name is surely better than the previous one"
        let _ =
        access.updateName(of: directoryToBeUpdated.id, to: newName)
            .flatMap { _ in access.read(id: directoryToBeUpdated.id) }
            .sink(receiveCompletion: { error in XCTFail("\(error)")},
                  receiveValue: { updatedFile in
                    XCTAssertNotNil(updatedFile)
                    XCTAssertEqual(updatedFile!.name, newName)
            })
    }

    func testReparentDocument() {
        let destinationDirectory = DirectoryStoreDescription.stub
        let noteToBeMoved = DocumentStoreDescription.stub

        let parentDirectory = DirectoryStoreDescription.stub(documents: [ noteToBeMoved ],
                                                             directories: [ destinationDirectory ])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc))
            .stub(root: parentDirectory)

        let _ =
        access.reparent(from: parentDirectory.id,
                        node: noteToBeMoved.id,
                        to: destinationDirectory.id)
            .flatMap { _ in access.children(of: parentDirectory.id) }
            .sink(receiveCompletion: { error in XCTFail("\(error)")},
                  receiveValue: { children in
                    XCTAssertEqual(children.count, 1)
                    switch children.first! {
                    case .file(let file):
                        XCTAssertEqual(file.store, noteToBeMoved.id)
                    default:
                        XCTFail("Moved document lost")
                    }
            })
    }

    func testCreateDirectory() {
        let access = DirectoryAccessImpl(access: DBAccess(moc: moc))
        let dirToBeCreated = DirectoryStoreDescription.stub

        let _ =
        access.root(from: dirToBeCreated)
            .flatMap { access.read(id: dirToBeCreated.id) }
            .sink(receiveCompletion: { error in XCTFail("\(error)")},
                  receiveValue: { result in
                    XCTAssertNotNil(result)
                    XCTAssertEqual(result!.id, dirToBeCreated.id)
                    XCTAssertEqual(result!.name, dirToBeCreated.name)
                    XCTAssertEqual(result!.created, dirToBeCreated.created)
            })
    }

    func testDeleteFile() {
        let fileToBeDeleted = DocumentStoreDescription.stub
        let unAffectedFile1 = DocumentStoreDescription.stub
        let unAffectedFile2 = DocumentStoreDescription.stub

        let parent = DirectoryStoreDescription.stub(
            documents: [
                fileToBeDeleted,
                unAffectedFile1,
                unAffectedFile2
            ],
            directories: []
        )

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc))
            .stub(root: parent)

        let _ =
        access.delete(child: fileToBeDeleted.id, of: parent.id)
            .flatMap { _ in access.children(of: parent.id) }
            .sink(receiveCompletion: { error in XCTFail("\(error)")},
                  receiveValue: { children in
                    XCTAssertEqual(children.count, 2)
                    XCTAssertNil(children.first { $0.id == fileToBeDeleted.id })
                    XCTAssertNotNil(children.first { $0.id == unAffectedFile1.id })
                    XCTAssertNotNil(children.first { $0.id == unAffectedFile2.id })
            })
    }

    func testDeleteDirectory() {
        let directoryToBeDeleted =
            DirectoryStoreDescription.stub(documents: [ DocumentStoreDescription.stub ],
                                           directories: [
                                            DirectoryStoreDescription.stub,
                                            DirectoryStoreDescription.stub
            ])
        let unAffectedDirectory1 = DirectoryStoreDescription.stub
        let unaffectedDirectory2 = DirectoryStoreDescription.stub

        let parent = DirectoryStoreDescription.stub(documents: [],
                                                    directories: [
                                                        directoryToBeDeleted,
                                                        unAffectedDirectory1,
                                                        unaffectedDirectory2
        ])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc))
            .stub(root: parent)
        let _ =
        access.delete(child: directoryToBeDeleted.id, of: parent.id)
            .flatMap { _ in access.read(id: directoryToBeDeleted.id) }
            .flatMap { directoryPlaceholder -> AnyPublisher<[FolderBrowserViewModel.Node], Error> in
                XCTAssertNil(directoryPlaceholder)
                return access.children(of: parent.id).eraseToAnyPublisher()
        }
        .flatMap { children -> AnyPublisher<DirectoryStoreLookupResult?, Error> in
            XCTAssertEqual(children.count, 2)
            return access.read(id: unAffectedDirectory1.id).eraseToAnyPublisher()
        }
        .flatMap { u1 -> AnyPublisher<DirectoryStoreLookupResult?, Error> in
            XCTAssertNotNil(u1)
            XCTAssertEqual(u1!.id, unAffectedDirectory1.id)
            return access.read(id: unaffectedDirectory2.id).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
        .sink(receiveCompletion: { error in XCTFail("\(error)") },
              receiveValue: { u2 in
                XCTAssertNotNil(u2)
                XCTAssertEqual(u2!.id, unaffectedDirectory2.id)
        })
    }

    func testMoveDirectory() {
        let newParent = DirectoryStoreDescription.stub
        let child = DirectoryStoreDescription.stub
        let parent = DirectoryStoreDescription.stub(documents: [ ],
                                                    directories: [ newParent, child ])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc)).stub(root: parent)

        let _ =
        access.reparent(from: parent.id, node: child.id, to: newParent.id)
            .flatMap { _ in access.children(of: newParent.id) }
            .flatMap { children -> AnyPublisher<[FolderBrowserViewModel.Node], Error> in
                XCTAssertEqual(children.count, 1)
                switch children.first! {
                case .directory(let dir):
                    XCTAssertEqual(dir.store, child.id)
                default:
                    XCTFail("Node type changed")
                }
                return access.children(of: parent.id).eraseToAnyPublisher()
        }.sink(receiveCompletion: { error in XCTFail("\(error)") },
               receiveValue: { childrenOfOldParent in
                XCTAssertEqual(childrenOfOldParent.count, 1)
        })
    }
}
