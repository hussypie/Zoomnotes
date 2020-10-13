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

    static func root(defaults: UserDefaults, access: DirectoryAccess) -> FolderBrowserViewModel {
        if let rootDirId: UUID = defaults.uuid(forKey: UserDefaultsKey.rootDirectoryId.rawValue) {
            do {
                guard let rootDir: DirectoryStoreLookupResult = try access.read(id: ID(rootDirId)) else {
                    fatalError("Cannot find root dir, although id is noted")
                }
                let children = try access.children(of: rootDir.id)

                return FolderBrowserViewModel(directoryId: rootDir.id,
                                              name: rootDir.name,
                                              nodes: children,
                                              access: access)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }

        let defaultID = UUID()
        let defaultRootDir = DirectoryStoreDescription(id: ID(defaultID),
                                                       created: Date(),
                                                       name: "Documents",
                                                       documents: [],
                                                       directories: [])
        do {
            try access.root(from: defaultRootDir)
            defaults.set(defaultID, forKey: UserDefaultsKey.rootDirectoryId.rawValue)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        return FolderBrowserViewModel(directoryId: defaultRootDir.id,
                                      name: defaultRootDir.name,
                                      nodes: [],
                                      access: access)
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

    func subFolderBrowserVM(for directory: DirectoryVM) -> FolderBrowserViewModel? {
        do {
            let children = try self.cdaccess.children(of: directory.store)

            return FolderBrowserViewModel(directoryId: directory.store,
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
                try self.cdaccess.noteModel(of: note.store) else { return nil }

            // swiftlint:disable:next force_cast
            let noteLevelAccess = (UIApplication.shared.delegate as! AppDelegate).noteLevelAccess

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
                onUpdateName: { name in
                    _ = try? self.cdaccess.updateName(of: note.store, to: name)
            })
        } catch let error {
            fatalError(error.localizedDescription)
        }
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
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.delete(child: dir.store, of: directoryId)
            case .file(let file):
                try self.cdaccess.delete(child: file.store, of: directoryId)
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

            try self.cdaccess.append(document: description, to: directoryId)
            self.nodes.append(.file(file))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createFolder(_ folder: DirectoryVM) {
        do {
            let description = DirectoryStoreDescription(id: folder.store,
                                                        created: folder.created,
                                                        name: folder.name,
                                                        documents: [],
                                                        directories: [])
            try self.cdaccess.append(directory: description, to: directoryId)
            self.nodes.append(.directory(folder))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func move(_ node: Node, to dest: DirectoryVM) {
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.reparent(from: directoryId,
                                           node: dir.store,
                                           to: dest.store)
            case .file(let file):
                try self.cdaccess.reparent(from: directoryId,
                                           node: file.store,
                                           to: dest.store)
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
                try self.cdaccess.updateName(of: dir.store, to: name)
            case .file(let file):
                try self.cdaccess.updateName(of: file.store, to: name)
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
                try self.cdaccess.updatePreviewImage(of: file.store, with: image)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }
    }
}
