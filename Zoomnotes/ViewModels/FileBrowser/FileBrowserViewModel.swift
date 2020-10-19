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
        let noteLevelAccess = (UIApplication.shared.delegate as! AppDelegate).noteLevelAccess

        return self.cdaccess
            .noteModel(of: note)
            .map { noteModel in
                guard let noteModel = noteModel else { return nil }

                let sublevelFactory: NoteEditorViewModel.SublevelFactory = { vm in
                    let subLevels =
                        noteModel.sublevels
                            .map { NoteChildVM(id: UUID(),
                                               preview: $0.preview,
                                               frame: $0.frame,
                                               commander: NoteLevelCommander(id: $0.id,
                                                                             editor: vm)) }

                    let images =
                        noteModel.images
                            .map { NoteChildVM(id: UUID(),
                                               preview: $0.preview,
                                               frame: $0.frame,
                                               commander: NoteImageCommander(id: $0.id,
                                                                             editor: vm)) }

                    return subLevels + images
                }

                return NoteEditorViewModel(
                    id: noteModel.id,
                    title: name,
                    sublevels: sublevelFactory,
                    drawing: noteModel.drawing,
                    access: noteLevelAccess,
                    onUpdateName: {
                        self.cdaccess
                            .updateName(of: note, to: $0)
                            .sink(receiveDone: { /* TODO logging */ },
                                  receiveError: { _ in /* TODO logging */ },
                                  receiveValue: { _ in /* TODO logging */ })
                            .store(in: &self.cancellables)

                })
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

    private func delete(_ node: FolderBrowserNode) {
        switch node.store {
        case .directory(let id):
            self.cdaccess
                .delete(child: id, of: directoryId)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)
        case .document(let id):
            self.cdaccess
                .delete(child: id, of: directoryId)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)
        }
    }

    private func create(_ node: FolderBrowserNode) {
        let createFactory: () -> AnyPublisher<Void, Error> = {
            switch node.store {
            case .directory(let id):
                return self.createFolder(id: id, created: node.lastModified, name: node.name)
            case .document(let id):
                return self.createFile(id: id,
                                       name: node.name,
                                       preview: node.preview.image,
                                       lastModified: node.lastModified)
            }
        }

        createFactory()
            .sink(receiveDone: { /* TODO: logging */ },
                  receiveError: { _ in },
                  receiveValue: {
                    self.nodes.append(node)
            })
            .store(in: &self.cancellables)
    }

    private func createFile(id: DocumentID,
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
                                       root: rootData)

        return self.cdaccess
            .append(document: description, to: directoryId)
    }

    private func createFolder(id: DirectoryID,
                              created: Date,
                              name: String
    ) -> AnyPublisher<Void, Error> {
        let description = DirectoryStoreDescription(id: id,
                                                    created: created,
                                                    name: name,
                                                    documents: [],
                                                    directories: [])

        return self.cdaccess.append(directory: description, to: directoryId)
    }

    private func move(_ node: FolderBrowserNode, to dest: DirectoryID) {
        switch node.store {
        case .directory(let id):
            self.cdaccess.reparent(from: directoryId,
                                   node: id,
                                   to: dest)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)
        case .document(let id):
            self.cdaccess.reparent(from: directoryId,
                                   node: id,
                                   to: dest)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)

        }
    }

    private func rename(_ node: FolderBrowserNode, to name: String) {
        switch node.store {
        case .directory(let dir):
            self.cdaccess
                .updateName(of: dir, to: name)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: { node.name = name })
                .store(in: &cancellables)
        case .document(let file):
            self.cdaccess
                .updateName(of: file, to: name)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: { node.name = name })
                .store(in: &cancellables)
        }

    }

    func process(command: FileBrowserCommand) {
        switch command {
        case .delete(let node):
            self.delete(node)

        case .createFile(let preview):
            let node = self.newFile()
            node.preview = CodableImage(wrapping: preview)
            self.create(node)

        case .createDirectory:
            self.create(self.newDirectory())

        case .move(let node, to: let dest):
            self.move(node, to: dest)

        case .rename(let node, to: let name):
            self.rename(node, to: name)

        case .update(let file, preview: let image):
            self.cdaccess
                .updatePreviewImage(of: file, with: image)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: { })
                .store(in: &cancellables)
        }
    }
}
