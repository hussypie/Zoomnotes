//
//  FileBrowserViewModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine
import CoreData
import PencilKit

class FolderBrowserViewModel: ObservableObject, FileBrowserCommandable {
    private let directoryId: DirectoryID
    @Published private(set) var nodes: [FolderBrowserNode]
    @Published private(set) var title: String

    private var cdaccess: DirectoryAccess
    private var cancellables: Set<AnyCancellable> = []

    static func root(defaults: UserDefaults, access: DirectoryAccess) -> AnyPublisher<FolderBrowserViewModel, Error> {
        if let rootDirId: UUID = defaults.uuid(forKey: UserDefaultsKey.rootDirectoryId.rawValue) {
            return access
                .read(id: ID(rootDirId))
                .flatMap { (rootDir: DirectoryStoreLookupResult?) -> AnyPublisher<FolderBrowserViewModel, Error> in
                    guard let rootDir = rootDir else {
                        fatalError("Root dir id noted, but not present in DB")
                    }
                    return access
                        .children(of: rootDir.id)
                        .map { children in
                            return FolderBrowserViewModel(directoryId: rootDir.id,
                                                          name: rootDir.name,
                                                          nodes: children,
                                                          access: access)
                        }.eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }

        let defaultID = UUID()
        let defaultRootDir = DirectoryStoreDescription(id: ID(defaultID),
                                                       created: Date(),
                                                       name: "Documents",
                                                       documents: [],
                                                       directories: [])

        return access.root(from: defaultRootDir)
            .map { _ in
                defaults.set(defaultID, forKey: UserDefaultsKey.rootDirectoryId.rawValue)
                return FolderBrowserViewModel(directoryId: defaultRootDir.id,
                                              name: defaultRootDir.name,
                                              nodes: [],
                                              access: access)
            }.eraseToAnyPublisher()
    }

    init(directoryId: DirectoryID,
         name: String,
         nodes: [FolderBrowserNode],
         access: DirectoryAccess
    ) {
        self.directoryId = directoryId
        self.nodes = nodes
        self.title = name

        self.cdaccess = access
    }

    func subFolderBrowserVM(for directory: DirectoryID,
                            with name: String
    ) -> AnyPublisher<FolderBrowserViewModel, Error> {
        return cdaccess
            .children(of: directory)
            .map { children in
                return FolderBrowserViewModel(directoryId: directory,
                                              name: name,
                                              nodes: children,
                                              access: self.cdaccess)

            }.eraseToAnyPublisher()
    }

    func noteEditorVM(for note: DocumentID, with name: String) -> AnyPublisher<NoteEditorViewModel?, Error> {
        // swiftlint:disable:next force_cast
        let appdelegate = (UIApplication.shared.delegate as! AppDelegate)
        let noteLevelAccess = NoteLevelAccessImpl(access: appdelegate.access,
                                                  document: note,
                                                  logger: appdelegate.logger)

        return self.cdaccess
            .noteModel(of: note)
            .map { lookupResult in
                guard let lookupResult = lookupResult else { return nil }

                let subLevels =
                    lookupResult.root.sublevels
                    .map { NoteChildVM(id: UUID(),
                                       preview: $0.preview,
                                       frame: $0.frame,
                                       store: .level($0.id)) }

                let images =
                    lookupResult.root.images
                    .map { NoteChildVM(id: UUID(),
                                       preview: $0.preview,
                                       frame: $0.frame,
                                       store: .image($0.id)) }

                let drawerSubLevels =
                    lookupResult.levelDrawer
                    .map { NoteChildVM(id: UUID(),
                                       preview: $0.preview,
                                       frame: $0.frame,
                                       store: .level($0.id)) }

                let drawerImages =
                    lookupResult.imageDrawer
                    .map { NoteChildVM(id: UUID(),
                                       preview: $0.preview,
                                       frame: $0.frame,
                                       store: .image($0.id)) }

                return NoteEditorViewModel(
                    id: lookupResult.root.id,
                    title: name,
                    sublevels: subLevels + images,
                    drawer: DrawerVM(nodes: drawerSubLevels + drawerImages),
                    drawing: lookupResult.root.drawing,
                    access: noteLevelAccess)
            }
            .eraseToAnyPublisher()
    }

    private func newFile() -> FolderBrowserNode {
        let defaultImage = UIImage.from(size: CGSize(width: 300, height: 200)).withBackground(color: UIColor.white)
        return FolderBrowserNode(id: UUID(),
                                 store: .document(ID(UUID())),
                                 preview: CodableImage(wrapping: defaultImage),
                                 name: "Untitled",
                                 lastModified: Date())
    }

    private func newDirectory() -> FolderBrowserNode {
        return FolderBrowserNode(id: UUID(),
                                 store: .directory(ID(UUID())),
                                 preview: CodableImage(wrapping: UIImage.folder()),
                                 name: "Untitled",
                                 lastModified: Date())
    }

    private func `switch`(
        id: FolderBrowserNodeStoreID,
        directory: (DirectoryID) -> AnyPublisher<Void, Error>,
        document: (DocumentID) -> AnyPublisher<Void, Error>
    ) -> AnyPublisher<Void, Error> {
        switch id {
        case .directory(let did):
            return directory(did)
        case .document(let docid):
            return document(docid)
        }
    }

    func delete(node: FolderBrowserNode) -> AnyPublisher<Void, Error> {
        return `switch`(
            id: node.store,
            directory: { [unowned self] id in self.cdaccess.delete(child: id, of: self.directoryId) },
            document: {  [unowned self] id in self.cdaccess.delete(child: id, of: self.directoryId) }
        ).map { [unowned self] _ in
            self.nodes = self.nodes.filter { $0.id != node.id }
        }.eraseToAnyPublisher()
    }

    func createFile(id: DocumentID,
                    name: String,
                    preview: UIImage,
                    lastModified: Date
    ) -> AnyPublisher<Void, Error> {
        let rootData = NoteLevelDescription(preview: preview,
                                            frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
                                            id: ID(UUID()),
                                            drawing: PKDrawing(),
                                            sublevels: [],
                                            images: [])

        let description: DocumentStoreDescription
            = DocumentStoreDescription(id: id,
                                       lastModified: lastModified,
                                       name: name,
                                       thumbnail: preview,
                                       imageDrawer: [],
                                       levelDrawer: [],
                                       imageTrash: [],
                                       levelTrash: [],
                                       root: rootData)

        return self.cdaccess
            .append(document: description, to: directoryId)
            .map { [unowned self] in
                self.nodes.append(
                    FolderBrowserNode(id: UUID(),
                                      store: .document(description.id),
                                      preview: CodableImage(wrapping: preview),
                                      name: name,
                                      lastModified: lastModified)
                )}.eraseToAnyPublisher()
    }

    func createFolder(id: DirectoryID,
                      created: Date,
                      name: String
    ) -> AnyPublisher<Void, Error> {
        let description = DirectoryStoreDescription(id: id,
                                                    created: created,
                                                    name: name,
                                                    documents: [],
                                                    directories: [])

        return self.cdaccess
            .append(directory: description, to: directoryId)
            .map { [unowned self] in
                self.nodes.append(
                    FolderBrowserNode(id: UUID(),
                                      store: .directory(description.id),
                                      preview: CodableImage(wrapping: UIImage.folder()),
                                      name: name,
                                      lastModified: created)
                )}.eraseToAnyPublisher()
    }

    func move(node: FolderBrowserNode, to dest: DirectoryID) -> AnyPublisher<Void, Error> {
        return `switch`(
            id: node.store,
            directory: { [unowned self] in self.cdaccess.reparent(from: directoryId, node: $0, to: dest) },
            document: { [unowned self] in self.cdaccess.reparent(from: directoryId, node: $0, to: dest) }
        ).map { [unowned self] in
            self.nodes = self.nodes.filter { $0.id != node.id }

        }.eraseToAnyPublisher()
    }

    func rename(node: FolderBrowserNode, to name: String) -> AnyPublisher<Void, Error> {
        `switch`(
            id: node.store,
            directory: { [unowned self] in self.cdaccess.updateName(of: $0, to: name) },
            document: { [unowned self] in self.cdaccess.updateName(of: $0, to: name) }
        ).map {  node.name = name }
        .eraseToAnyPublisher()
    }

    func update(doc: DocumentID, preview: UIImage) -> AnyPublisher<Void, Error> {
        self.cdaccess
            .updatePreviewImage(of: doc, with: preview)
    }
}
