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

enum FileBrowserCommand {
    case createFile
    case createDirectory
    case delete(Node)
    case move(Node, to: DirectoryVM)
    case rename(Node, to: String)
}

enum Node: Codable, Equatable {
    case directory(DirectoryVM)
    case file(FileVM)

    var id: UUID {
        switch self {
        case .directory(let dir):
            return dir.id
        case .file(let file):
            return file.id
        }
    }

    var name: String {
        switch self {
        case .directory(let dir):
            return dir.name
        case .file(let file):
            return file.name
        }
    }

    var date: Date {
        switch self {
        case .directory(let dir):
            return dir.created
        case .file(let file):
            return file.lastModified
        }
    }

    enum CodingKeys: CodingKey {
        case rawValue
        case associatedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case 0:
            let doc = try container.decode(DirectoryVM.self, forKey: .associatedValue)
            self = .directory(doc)
        case 1:
            let folder = try container.decode(FileVM.self, forKey: .associatedValue)
            self = .file(folder)
        default:
            fatalError("unknown coding key")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .directory(let dir):
            try container.encode(0, forKey: .rawValue)
            try container.encode(dir, forKey: .associatedValue)
        case .file(let file):
            try container.encode(1, forKey: .rawValue)
            try container.encode(file, forKey: .associatedValue)
        }
    }
}

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

class FolderBrowserViewModel: ObservableObject {
    private let directoryId: UUID
    @Published private(set) var nodes: [Node]
    @Published private(set) var title: String

    private var cdaccess: CoreDataAccess

    static func root(defaults: UserDefaults, using moc: NSManagedObjectContext) -> FolderBrowserViewModel {
        let access = CoreDataAccess(using: moc)
        if let rootDirId: UUID = defaults.uuid(forKey: UserDefaultsKey.rootDirectoryId.rawValue) {
            do {
                guard let rootDir = try access.directory.read(id: rootDirId) else {
                    fatalError("Cannot find root dir, although id is noted")
                }
                let directoryChildren =
                    try access.directory
                        .children(of: rootDir.id)
                        .map { Node.directory($0) }

                let documentChildren =
                    try access.file
                        .children(of: rootDir.id)
                        .map { Node.file($0) }

                return FolderBrowserViewModel(directoryId: rootDir.id,
                                              name: rootDir.name,
                                              nodes: directoryChildren + documentChildren,
                                              access: access)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }

        let defaultRootDir = DirectoryVM.fresh(name: "Documents", created: Date())
        do {
            try access.directory.create(from: defaultRootDir, with: defaultRootDir.id)
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
            let directoryChildren =
                try self.cdaccess.directory
                    .children(of: directory.id)
                    .map { Node.directory($0) }
            let documentChilden =
                try self.cdaccess.file
                    .children(of: directory.id)
                    .map { Node.file($0) }
            return FolderBrowserViewModel(directoryId: directory.id,
                                          name: directory.name,
                                          nodes: directoryChildren + documentChilden,
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
                try self.cdaccess.directory.delete(directory: dir)
            case .file(let file):
                try self.cdaccess.file.delete(file)
            }
            self.nodes = self.nodes.filter { $0.id != node.id }
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createFile(_ file: FileVM) {
        do {
            try self.cdaccess.file.create(from: file, with: self.directoryId)
            self.nodes.append(.file(file))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createFolder(_ folder: DirectoryVM) {
        do {
            try self.cdaccess.directory.create(from: folder, with: self.directoryId)
            self.nodes.append(.directory(folder))
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func move(_ node: Node, to dest: DirectoryVM) {
        do {
            switch node {
            case .directory(let dir):
                try self.cdaccess.directory.reparent(from: self.directoryId, node: dir, to: dest.id)
            case .file(let file):
                try self.cdaccess.file.reparent(from: self.directoryId, file: file, to: dest.id)
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
                try self.cdaccess.directory.updateName(for: dir, to: name)
            case .file(let file):
                try self.cdaccess.file.updateName(of: file, to: name)
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

        case .createFile:
            self.createFile(self.newFile())

        case .createDirectory:
            self.createFolder(self.newDirectory())

        case .move(let node, to: let dest):
            self.move(node, to: dest)

        case .rename(let node, to: let name):
            self.rename(node, to: name)
        }
    }
}

extension FolderBrowserViewModel {
    static var stub: FolderBrowserViewModel {
        return FolderBrowserViewModel(directoryId: UUID(),
                                      name: "Stub folder",
                                      nodes: [],
                                      access: CoreDataAccess.stub)
    }

    static func stub(nodes: [Node]) -> FolderBrowserViewModel {
        return FolderBrowserViewModel(directoryId: UUID(),
                                      name: "Stub folder",
                                      nodes: nodes,
                                      access: CoreDataAccess.stub)
    }
}
