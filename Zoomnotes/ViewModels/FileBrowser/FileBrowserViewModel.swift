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
    private let directoryId: UUID
    @Published private(set) var nodes: [Node]
    @Published private(set) var title: String

    private var cdaccess: DirectoryAccess

    static func root(defaults: UserDefaults, access: DirectoryAccess) -> FolderBrowserViewModel {
        if let rootDirId: UUID = defaults.uuid(forKey: UserDefaultsKey.rootDirectoryId.rawValue) {
            do {
                guard let rootDir: DirectoryStoreLookupResult = try access.read(id: DirectoryStoreId(id: rootDirId)) else {
                    fatalError("Cannot find root dir, although id is noted")
                }
                let children = try access.children(of: rootDir.id)

                return FolderBrowserViewModel(directoryId: rootDir.id.id,
                                              name: rootDir.name,
                                              nodes: children,
                                              access: access)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }

        let defaultRootDir = DirectoryStoreDescription(id: UUID(),
                                                       created: Date(),
                                                       name: "Documents",
                                                       documents: [],
                                                       directories: [])
        do {
            try access.root(from: defaultRootDir)
            defaults.set(defaultRootDir.id.id, forKey: UserDefaultsKey.rootDirectoryId.rawValue)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        return FolderBrowserViewModel(directoryId: defaultRootDir.id.id,
                                      name: defaultRootDir.name,
                                      nodes: [],
                                      access: access)
    }

    init(directoryId: UUID, name: String, nodes: [Node], access: DirectoryAccess) {
        self.directoryId = directoryId
        self.nodes = nodes
        self.title = name

        self.cdaccess = access
    }

    func subFolderBrowserVM(for directory: DirectoryVM) -> FolderBrowserViewModel? {
        do {
            let children = try self.cdaccess.children(of: DirectoryStoreId(id: directory.id))

            return FolderBrowserViewModel(directoryId: directory.id,
                                          name: directory.name,
                                          nodes: children,
                                          access: self.cdaccess)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func noteEditorVM(for note: FileVM) -> NoteEditorViewModel? {
        do {
            guard let noteModel =
                try self.cdaccess.noteModel(of: DocumentStoreId(id: note.id)) else { return nil }

            // swiftlint:disable:next force_cast
            let noteLevelAccess = (UIApplication.shared.delegate as! AppDelegate).noteLevelAccess

            let subLevels =
                noteModel.sublevels
                    .map { NoteChildVM(id: $0.id,
                                       preview: $0.preview,
                                       frame: $0.frame)}
                    .map { ($0.id, $0) }

            return NoteEditorViewModel(
                id: noteModel.id,
                title: note.name,
                sublevels: Dictionary.init(uniqueKeysWithValues: subLevels),
                drawing: noteModel.drawing,
                access: noteLevelAccess,
                drawer: [:],
                onUpdateName: { name in
                    _ = try? self.cdaccess.updateName(of: DocumentStoreId(id: note.id),
                                                      to: name)
            })
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func newFile() -> FileVM {
        let defaultImage = UIImage.from(size: CGSize(width: 300, height: 200)).withBackground(color: UIColor.white)
        return FileVM.fresh(preview: defaultImage, name: "Untitled", created: Date())
    }

    private func newDirectory() -> DirectoryVM {
        return DirectoryVM.fresh(name: "Untitled", created: Date())
    }

    private func delete(_ node: Node) {
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.delete(child: DirectoryStoreId(id: dir.id), of: DirectoryStoreId(id: directoryId))
            case .file(let file):
                try self.cdaccess.delete(child: DocumentStoreId(id: file.id), of: DirectoryStoreId(id: directoryId))
            }
            self.nodes = self.nodes.filter { $0.id != node.id }
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createFile(_ file: FileVM, with preview: UIImage) {
        do {
            let rootData = NoteLevelDescription(preview: preview,
                                                frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
                                                id: UUID(),
                                                drawing: PKDrawing(),
                                                sublevels: [],
                                                images: [])
            let description: DocumentStoreDescription
                = DocumentStoreDescription(id: file.id,
                                           lastModified: file.lastModified,
                                           name: file.name,
                                           thumbnail: preview,
                                           root: rootData)

            try self.cdaccess.append(document: description, to: DirectoryStoreId(id: directoryId))
            self.nodes.append(.file(file))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createFolder(_ folder: DirectoryVM) {
        do {
            let description = DirectoryStoreDescription(id: folder.id,
                                                        created: folder.created,
                                                        name: folder.name,
                                                        documents: [],
                                                        directories: [])
            try self.cdaccess.append(directory: description, to: DirectoryStoreId(id: directoryId))
            self.nodes.append(.directory(folder))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func move(_ node: Node, to dest: DirectoryVM) {
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.reparent(from: DirectoryStoreId(id: self.directoryId),
                                           node: DirectoryStoreId(id: dir.id),
                                           to: DirectoryStoreId(id: dest.id))
            case .file(let file):
                try self.cdaccess.reparent(from: DirectoryStoreId(id: self.directoryId),
                                           node: DocumentStoreId(id: file.id),
                                           to: DirectoryStoreId(id: dest.id))
            }
            self.nodes = self.nodes.filter { $0.id != node.id }
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func rename(_ node: Node, to name: String) {
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.updateName(of: DirectoryStoreId(id: dir.id), to: name)
            case .file(let file):
                try self.cdaccess.updateName(of: DocumentStoreId(id: file.id), to: name)
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
        } catch let error {
            fatalError(error.localizedDescription)
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
            do {
                try self.cdaccess.updatePreviewImage(of: DocumentStoreId(id: file.id), with: image)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }
    }
}
