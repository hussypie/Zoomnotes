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

    func testCreateFile() {
        let root = DirectoryStoreDescription(id: ID(UUID()),
                                             created: Date(),
                                             name: "Root",
                                             documents: [],
                                             directories: [])

        let access = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger()).stub(root: root)

        let rootLevel = NoteLevelDescription.stub(parent: nil)
        let fileToBeCreated =
            DocumentStoreDescription(id: ID(UUID()),
                                     lastModified: Date(),
                                     name: "New file",
                                     thumbnail: .checkmark,
                                     imageDrawer: [],
                                     levelDrawer: [],
                                     imageTrash: [],
                                     levelTrash: [],
                                     root: rootLevel)

        let noteLevelAccess = NoteLevelAccessImpl(access: DBAccess(moc: moc), document: fileToBeCreated.id, logger: TestLogger())

        _ = access
            .append(document: fileToBeCreated, to: root.id)
            .flatMap({ access.children(of: root.id) })
            .flatMap { result -> AnyPublisher<NoteLevelDescription?, Error> in
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result.first!.name, fileToBeCreated.name)
                XCTAssertEqual(result.first!.lastModified, fileToBeCreated.lastModified)
                XCTAssert(result.first!.storeEquals(fileToBeCreated.id))

                return noteLevelAccess.read(level: rootLevel.id).eraseToAnyPublisher()
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { rootLevel2 in
                XCTAssertNotNil(rootLevel2)
                XCTAssertEqual(rootLevel2!.id, rootLevel.id)
        })

    }

    func testUpdateFileLastModified() {
        let fileToBeUpdated = DocumentStoreDescription.stub
        let rootId = UUID()

        let root = DirectoryStoreDescription.stub(
            id: rootId,
            documents: [
                DocumentStoreDescription.stub,
                fileToBeUpdated,
                DocumentStoreDescription.stub
            ],
            directories: []
        )

        let newDate = Date().advanced(by: 24*68*60)

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: root)
            .flatMap { access in
                access.updateLastModified(of: fileToBeUpdated.id, with: newDate)
                    .flatMap { _ in access.children(of: root.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { children in
                XCTAssertEqual(children.count, 3)
                let updatedFile = children.first { $0.storeEquals(fileToBeUpdated.id) }!
                XCTAssertEqual(updatedFile.lastModified, newDate)
        })
    }

    func testUpdateFileName() {
        let fileToBeUpdated = DocumentStoreDescription.stub
        let rootId = UUID()
        let root = DirectoryStoreDescription.stub(
            id: rootId,
            documents: [
                DocumentStoreDescription.stub,
                fileToBeUpdated,
                DocumentStoreDescription.stub
            ],
            directories: []
        )

        let newName = "This name is surely better than the prevoius one"

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: root)
            .flatMap { access in
                access.updateName(of: fileToBeUpdated.id, to: newName)
                    .flatMap { _ in access.children(of: root.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { children in
                XCTAssertEqual(children.count, 3)
                let updatedFile = children.first { $0.storeEquals(fileToBeUpdated.id) }!
                XCTAssertEqual(updatedFile.name, newName)
        })
    }

    func testUpdateDirectoryName() {
        let directoryToBeUpdated = DirectoryStoreDescription.stub
        let rootId = UUID()
        let newName = "This name is surely better than the previous one"

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: DirectoryStoreDescription.stub(
                id: rootId,
                documents: [],
                directories: [
                    DirectoryStoreDescription.stub,
                    directoryToBeUpdated,
                    DirectoryStoreDescription.stub
            ]))
            .flatMap { access in
                access.updateName(of: directoryToBeUpdated.id, to: newName)
                    .flatMap { _ in access.read(id: directoryToBeUpdated.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { updatedFile in
                XCTAssertNotNil(updatedFile)
                XCTAssertEqual(updatedFile!.name, newName)
        })
    }

    func testReparentDocument() {
        let destinationDirectory = DirectoryStoreDescription.stub
        let noteToBeMoved = DocumentStoreDescription.stub

        let rootId = UUID()
        let parentDirectory = DirectoryStoreDescription.stub(
            id: rootId,
            documents: [ noteToBeMoved ],
            directories: [ destinationDirectory ]
        )

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: parentDirectory)
            .flatMap { access in
                access.reparent(from: parentDirectory.id,
                                node: noteToBeMoved.id,
                                to: destinationDirectory.id)
                    .flatMap { _ in access.children(of: destinationDirectory.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { children in
                XCTAssertEqual(children.count, 1)
                XCTAssertTrue(children.first!.storeEquals(noteToBeMoved.id))
        })
    }

    func testCreateDirectory() {
        let access = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
        let dirToBeCreated = DirectoryStoreDescription.stub

        _ = access.root(from: dirToBeCreated)
            .flatMap { access.read(id: dirToBeCreated.id) }
            .sink(receiveDone: { XCTAssertTrue(true, "OK") },
                  receiveError: { XCTFail($0.localizedDescription) },
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

        let rootId = UUID()
        let parent = DirectoryStoreDescription.stub(
            id: rootId,
            documents: [
                fileToBeDeleted,
                unAffectedFile1,
                unAffectedFile2
            ],
            directories: []
        )

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: parent)
            .flatMap { access in
                access.delete(child: fileToBeDeleted.id, of: parent.id)
                    .flatMap { _ in access.children(of: parent.id) }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
              receiveError: { XCTFail($0.localizedDescription) },
              receiveValue: { children in
                XCTAssertEqual(children.count, 2)
                XCTAssertNil(children.first { $0.storeEquals(fileToBeDeleted.id) })
                XCTAssertNotNil(children.first { $0.storeEquals(unAffectedFile1.id) })
                XCTAssertNotNil(children.first { $0.storeEquals(unAffectedFile2.id) })
        })
    }

    func testDeleteDirectory() {
        let directoryToBeDeleted =
            DirectoryStoreDescription.stub(
                id: UUID(),
                documents: [ DocumentStoreDescription.stub ],
                directories: [
                    DirectoryStoreDescription.stub,
                    DirectoryStoreDescription.stub
            ])
        let unAffectedDirectory1 = DirectoryStoreDescription.stub
        let unaffectedDirectory2 = DirectoryStoreDescription.stub

        let rootId = UUID()
        let parent = DirectoryStoreDescription.stub(
            id: rootId,
            documents: [],
            directories: [
                directoryToBeDeleted,
                unAffectedDirectory1,
                unaffectedDirectory2
        ])

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: parent)
            .flatMap { access -> AnyPublisher<DirectoryStoreLookupResult?, Error> in
                access.delete(child: directoryToBeDeleted.id, of: parent.id)
                    .flatMap { _ in access.read(id: directoryToBeDeleted.id) }
                    .flatMap { directoryPlaceholder -> AnyPublisher<[FolderBrowserNode], Error> in
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
        }.sink(receiveDone: { XCTAssert(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription) },
               receiveValue: { u2 in
                XCTAssertNotNil(u2)
                XCTAssertEqual(u2!.id, unaffectedDirectory2.id)
        })
    }

    func testMoveDirectory() {
        let newParent = DirectoryStoreDescription.stub
        let child = DirectoryStoreDescription.stub
        let rootId = UUID()
        let parent = DirectoryStoreDescription.stub(
            id: rootId,
            documents: [ ],
            directories: [ newParent, child ])

        _ = DirectoryAccessImpl(access: DBAccess(moc: moc), logger: TestLogger())
            .stubF(root: parent)
            .flatMap { access in
                return access.reparent(from: parent.id, node: child.id, to: newParent.id)
                    .flatMap { _ in access.children(of: newParent.id) }
                    .flatMap { children -> AnyPublisher<[FolderBrowserNode], Error> in
                        XCTAssertEqual(children.count, 1)
                        XCTAssertTrue(children.first!.storeEquals(child.id))
                        return access.children(of: parent.id).eraseToAnyPublisher()
                }
        }.sink(receiveDone: { XCTAssertTrue(true, "OK") },
               receiveError: { XCTFail($0.localizedDescription)},
               receiveValue: { childrenOfOldParent in
                XCTAssertEqual(childrenOfOldParent.count, 1)
        })
    }
}
