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

class FileVM: NSObject, ObservableObject, Codable {
    let id: UUID
    var preview: CodableImage
    var name: String
    var lastModified: Date

    required init(id: UUID, preview: UIImage, name: String, lastModified: Date) {
        self.id = id
        self.preview = CodableImage(wrapping: preview)
        self.name = name
        self.lastModified = lastModified
    }

    static func fresh(preview: UIImage, name: String, created on: Date) -> FileVM {
        return FileVM(id: UUID(),
                      preview: preview,
                      name: name,
                      lastModified: on)
    }

}

class DirectoryVM: NSObject, ObservableObject, Codable {
    let id: UUID
    var name: String
    var created: Date

    required init(id: UUID, name: String, created: Date) {
        self.id = id
        self.name = name
        self.created = created
    }

    static func fresh(name: String, created: Date) -> DirectoryVM {
        return DirectoryVM(id: UUID(), name: name, created: created)
    }

    static var `default`: DirectoryVM {
        return DirectoryVM.fresh(name: "Documents", created: Date())
    }
}

class FolderBrowserViewModel: ObservableObject, FileBrowserCommandable {
    private let directoryId: UUID
    @Published private(set) var nodes: [Node]
    @Published private(set) var title: String

    private var cdaccess: CoreDataAccess

    static func root(defaults: UserDefaults, using moc: NSManagedObjectContext) -> FolderBrowserViewModel {
        let access = CoreDataAccess(directory: DirectoryAccessImpl(using: moc),
                                    file: DocumentAccessImpl(using: moc))

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
            let newNoteData = NoteModel.default(id: UUID(),
                                                image: preview,
                                                frame: CGRect(x: 0,
                                                              y: 0,
                                                              width: preview.size.width,
                                                              height: preview.size.height))

            let newNoteDataSerialized = try newNoteData.serialize()
            let description: DocumentStoreDescription
                = DocumentStoreDescription(data: newNoteDataSerialized,
                                           id: file.id,
                                           lastModified: file.lastModified,
                                           name: file.name,
                                           thumbnail: preview)

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
