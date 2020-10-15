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
    @Published private(set) var nodes: [Node]
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
         nodes: [Node],
         access: DirectoryAccess
    ) {
        self.directoryId = directoryId
        self.nodes = nodes
        self.title = name

        self.cdaccess = access
    }

    func subFolderBrowserVM(for directory: DirectoryVM) -> AnyPublisher<FolderBrowserViewModel, Error> {
        return cdaccess
            .children(of: directory.store)
            .map { children in
                return FolderBrowserViewModel(directoryId: directory.store,
                                              name: directory.name,
                                              nodes: children,
                                              access: self.cdaccess)

        }.eraseToAnyPublisher()
    }

    func noteEditorVM(for note: FileVM) -> AnyPublisher<NoteEditorViewModel?, Error> {
        // swiftlint:disable:next force_cast
        let noteLevelAccess = (UIApplication.shared.delegate as! AppDelegate).noteLevelAccess

        return self.cdaccess
            .noteModel(of: note.store)
            .map { noteModel in
                guard let noteModel = noteModel else { return nil }
                let subLevels =
                    noteModel.sublevels
                        .map { NoteChildVM(id: UUID(),
                                           preview: $0.preview,
                                           frame: $0.frame,
                                           commander: NoteLevelCommander(id: $0.id)) }

                let images =
                    noteModel.images
                        .map { NoteChildVM(id: UUID(),
                                           preview: $0.preview,
                                           frame: $0.frame,
                                           commander: NoteImageCommander(id: $0.id)) }

                return NoteEditorViewModel(
                    id: noteModel.id,
                    title: note.name,
                    sublevels: subLevels + images,
                    drawing: noteModel.drawing,
                    access: noteLevelAccess,
                    onUpdateName: { self.cdaccess.updateName(of: note.store, to: $0) }
                )
        }
        .eraseToAnyPublisher()
    }

    private func newFile() -> FileVM {
        let defaultImage = UIImage.from(size: CGSize(width: 300, height: 200)).withBackground(color: UIColor.white)
        return FileVM(id: UUID(),
                      store: ID(UUID()),
                      preview: defaultImage,
                      name: "Untitled",
                      lastModified: Date())
    }

    private func newDirectory() -> DirectoryVM {
        return DirectoryVM(id: UUID(),
                           store: ID(UUID()),
                           name: "Untitled",
                           created: Date())

    }

    private func delete(_ node: Node) {
        switch node {
        case .directory(let dir):
            self.cdaccess
                .delete(child: dir.store, of: directoryId)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)
        case .file(let file):
            self.cdaccess
                .delete(child: file.store, of: directoryId)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)
        }
    }

    private func createFile(_ file: FileVM, with preview: UIImage) {

        let rootData = NoteLevelDescription(preview: preview,
                                            frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
                                            id: ID(UUID()),
                                            drawing: PKDrawing(),
                                            sublevels: [],
                                            images: [])
        let description: DocumentStoreDescription
            = DocumentStoreDescription(id: file.store,
                                       lastModified: file.lastModified,
                                       name: file.name,
                                       thumbnail: preview,
                                       root: rootData)

        self.cdaccess
            .append(document: description, to: directoryId)
            .sink(receiveCompletion: { _ in return }, // TODO
                receiveValue: {
                    self.nodes.append(.file(file))
            })
            .store(in: &cancellables)
    }

    private func createFolder(_ folder: DirectoryVM) {
        let description = DirectoryStoreDescription(id: folder.store,
                                                    created: folder.created,
                                                    name: folder.name,
                                                    documents: [],
                                                    directories: [])
        self.cdaccess.append(directory: description, to: directoryId)
            .sink(receiveCompletion: { _ in return }, // TODO
                receiveValue: {
                    self.nodes.append(.directory(folder))
            })
            .store(in: &cancellables)
    }

    private func move(_ node: Node, to dest: DirectoryVM) {
        switch node {
        case .directory(let dir):
            self.cdaccess.reparent(from: directoryId,
                                   node: dir.store,
                                   to: dest.store)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)
        case .file(let file):
            self.cdaccess.reparent(from: directoryId,
                                   node: file.store,
                                   to: dest.store)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: {
                        self.nodes = self.nodes.filter { $0.id != node.id }
                })
                .store(in: &cancellables)

        }
    }

    private func rename(_ node: Node, to name: String) {
        switch node {
        case .directory(let dir):
            self.cdaccess
                .updateName(of: dir.store, to: name)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: { })
                .store(in: &cancellables)
        case .file(let file):
            self.cdaccess
                .updateName(of: file.store, to: name)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: { })
                .store(in: &cancellables)
        }

        self.nodes = self.nodes.map {
            if $0.id == node.id {
                switch $0 {
                case .directory(let dir):
                    dir.name = name

                case .file(let file):
                    file.name = name

                }
            }
            return $0
        }

    }

    func process(command: FileBrowserCommand) {
        switch command {
        case .delete(let node):
            self.delete(node)

        case .createFile(let preview):
            self.createFile(self.newFile(), with: preview)

        case .createDirectory:
            self.createFolder(self.newDirectory())

        case .move(let node, to: let dest):
            self.move(node, to: dest)

        case .rename(let node, to: let name):
            self.rename(node, to: name)

        case .update(let file, preview: let image):
            self.cdaccess
                .updatePreviewImage(of: file.store, with: image)
                .sink(receiveCompletion: { _ in return }, // TODO
                    receiveValue: { })
                .store(in: &cancellables)
        }
    }
}
