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

    private var cdaccess: CoreDataAccess

    static func root(defaults: UserDefaults, access: CoreDataAccess) -> FolderBrowserViewModel {
        if let rootDirId: UUID = defaults.uuid(forKey: UserDefaultsKey.rootDirectoryId.rawValue) {
            do {
                guard let rootDir = try access.directory.read(id: rootDirId) else {
                    fatalError("Cannot find root dir, although id is noted")
                }
                let children = try access.directory.children(of: rootDirId)

                return FolderBrowserViewModel(directoryId: rootDir.id,
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
                                                       documentChildren: [],
                                                       directoryChildren: [])
        do {
            try access.directory.create(from: defaultRootDir)
            defaults.set(defaultRootDir.id, forKey: UserDefaultsKey.rootDirectoryId.rawValue)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        return FolderBrowserViewModel(directoryId: defaultRootDir.id,
                                      name: defaultRootDir.name,
                                      nodes: [],
                                      access: access)
    }

    init(directoryId: UUID, name: String, nodes: [Node], access: CoreDataAccess) {
        self.directoryId = directoryId
        self.nodes = nodes
        self.title = name

        self.cdaccess = access
    }

    func subFolderBrowserVM(for directory: DirectoryVM) -> FolderBrowserViewModel? {
        do {
            let children = try self.cdaccess.directory.children(of: directory.id)

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
            guard let noteModel = try self.cdaccess.file.noteModel(of: note.id) else { return nil }

            // swiftlint:disable:next force_cast
            let moc = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

            let subLevels =
                noteModel.sublevels
                    .map { NoteLevelVM(id: $0.id,
                                       preview: UIImage(data: $0.preview)!,
                                       frame: $0.frame)}
                    .map { ($0.id, $0) }

            return NoteEditorViewModel(id: noteModel.id,
                                       title: note.name,
                                       sublevels: Dictionary.init(uniqueKeysWithValues: subLevels),
                                        drawing: noteModel.drawing,
                                       access: NoteLevelAccessImpl(using: moc),
                                        drawer: [:],
                                        onUpdateName: { name in
                                            _ = try? self.cdaccess.file.updateName(of: note.id, to: name)
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
                try self.cdaccess.directory.delete(child: .directory(dir.id), of: directoryId)
            case .file(let file):
                try self.cdaccess.directory.delete(child: .document(file.id), of: directoryId)
            }
            self.nodes = self.nodes.filter { $0.id != node.id }
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createFile(_ file: FileVM, with preview: UIImage) {
        do {
            let rootData = NoteLevelDescription(parent: nil,
                                                preview: preview.pngData()!,
                                                frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
                                                id: UUID(),
                                                drawing: PKDrawing(),
                                                sublevels: [])
            let description: DocumentStoreDescription
                = DocumentStoreDescription(id: file.id,
                                           lastModified: file.lastModified,
                                           name: file.name,
                                           thumbnail: preview,
                                           root: rootData)

            try self.cdaccess.directory.append(document: description, to: directoryId)
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
                                                        documentChildren: [],
                                                        directoryChildren: [])
            try self.cdaccess.directory.create(from: description)
            self.nodes.append(.directory(folder))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func move(_ node: Node, to dest: DirectoryVM) {
        do {
            let taggedId: DirectoryAccessNode
            switch node {
            case .directory(let dir):
                taggedId = .directory(dir.id)
            case .file(let file):
                taggedId = .document(file.id)
            }

            try self.cdaccess.directory.reparent(from: self.directoryId, node: taggedId, to: dest.id)

            self.nodes = self.nodes.filter { $0.id != node.id }
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func rename(_ node: Node, to name: String) {
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.directory.updateName(id: dir.id, to: name)
            case .file(let file):
                try self.cdaccess.file.updateName(of: file.id, to: name)
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
        }
    }
}
