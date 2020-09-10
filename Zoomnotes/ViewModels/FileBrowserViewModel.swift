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
    let id = UUID()

    var preview: CodableImage
    var name: String
    var lastModified: Date

    required init(preview: UIImage, name: String, lastModified: Date) {
        self.preview = CodableImage(wrapping: preview)
        self.name = name
        self.lastModified = lastModified
    }
}

class DirectoryVM: NSObject, ObservableObject, Codable {
    let id = UUID()
    var nodes: [Node]
    var name: String
    var created: Date

    required init(name: String, created: Date, nodes: [Node]) {
        self.name = name
        self.created = created
        self.nodes = nodes
    }

    static var `default`: DirectoryVM {
        return DirectoryVM(name: "Documents", created: Date(), nodes: [])
    }
}

class FolderBrowserViewModel: ObservableObject {
    private var folderModel: DirectoryVM

    @Published private(set) var nodes: [Node]
    @Published private(set) var title: String

    private var cancellables: Set<AnyCancellable> = []

    static func root() -> FolderBrowserViewModel {
        return FolderBrowserViewModel(folder: DirectoryAccess().root())
    }

    init(folder: DirectoryVM) {
        self.folderModel = folder

        self.nodes = folder.nodes
        self.title = folder.name

        self.$nodes
            .sink(receiveValue: { self.folderModel.nodes = $0})
            .store(in: &cancellables)
    }

    private func newFile() -> Node {
        let defaultImage = UIImage.from(size: CGSize(width: 300, height: 200)).withBackground(color: UIColor.white)
        return .file(FileVM(preview: defaultImage, name: "Untitled", lastModified: Date()))
    }

    private func newDirectory() -> Node {
        return .directory(DirectoryVM(name: "Untitled", created: Date(), nodes: []))
    }

    private func move(_ node: Node, to dest: DirectoryVM) {
        guard let selectedNodeIdx = self.folderModel.nodes.firstIndex(where: { $0.id == node.id }) else {
            return
        }
        self.nodes.remove(at: selectedNodeIdx)
        dest.nodes.append(node)
    }

    func process(command: FileBrowserCommand) {
        switch command {
        case .delete(let node):
            self.nodes = self.nodes.filter { $0.id != node.id }

        case .createFile:
            self.nodes.append(self.newFile())

        case .createDirectory:
            self.nodes.append(self.newDirectory())

        case .move(let node, to: let dest):
            self.move(node, to: dest)

        case .rename(let node, to: let name):
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
    }
}

extension FolderBrowserViewModel {
    static var stub: FolderBrowserViewModel {
        let dir = DirectoryVM(name: "Documents", created: Date(), nodes: [])
        let vm = FolderBrowserViewModel(folder: dir)

        return vm
    }

    static func stub(nodes: [Node]) -> FolderBrowserViewModel {
        let dir = DirectoryVM(name: "Documents", created: Date(), nodes: nodes)
        let vm = FolderBrowserViewModel(folder: dir)

        return vm
    }
}
