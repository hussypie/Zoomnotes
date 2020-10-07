//
//  NoteEditorViewModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 06..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit
import Combine
import CoreData

class NoteEditorViewModel: ObservableObject, NoteEditorCommandable {
    @Published var title: String
    @Published var drawing: PKDrawing
    @Published var nodes: [UUID: NoteChildVM]
    @Published var drawerContents: [UUID: NoteChildVM]

    private let id: UUID
    private let access: NoteLevelAccess
    private let onUpdateName: (String) -> Void

    let eventSubject = PassthroughSubject<NoteEditorCommand, Never>()
    private var cancellables: Set<AnyCancellable> = []

    init(id: UUID,
         title: String,
         sublevels: [UUID: NoteChildVM],
         drawing: PKDrawing,
         access: NoteLevelAccess,
         drawer: [UUID: NoteChildVM],
         onUpdateName: @escaping (String) -> Void
    ) {
        self.id = id
        self.title = title
        self.nodes = sublevels
        self.drawing = drawing

        self.onUpdateName = onUpdateName
        self.drawerContents = drawer

        self.access = access

        self.$title
            .sink { self.onUpdateName($0) }
            .store(in: &cancellables)
    }

    func childViewModel(for level: NoteChildVM) -> NoteEditorViewModel? {
        guard let subLevel = try? self.access.read(level: level.id) else { return nil }
        let subSubLevels = subLevel.sublevels
            .map { NoteChildVM(id: $0.id,
                               preview: $0.preview,
                               frame: $0.frame,
                               commander: NoteLevelCommander()) }
            .map { ($0.id, $0) }

        let subSubImages = subLevel.images
            .map { NoteChildVM(id: $0.id,
                               preview: $0.preview,
                               frame: $0.frame,
                               commander: NoteImageCommander()) }
            .map { ($0.id, $0) }

        return NoteEditorViewModel(id: level.id,
                                   title: self.title,
                                   sublevels: Dictionary.init(uniqueKeysWithValues: subSubLevels + subSubImages),
                                   drawing: subLevel.drawing,
                                   access: self.access,
                                   drawer: self.drawerContents,
                                   onUpdateName: self.onUpdateName)
    }

    private func moveLevel(level: NoteChildVM, to destinationFrame: CGRect) {
        do {
            try access.update(frame: destinationFrame, for: level.id)
            nodes[level.id]!.frame = destinationFrame
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func removeLevel(level: NoteChildVM) {
        do {
            try access.remove(level: level.id, from: id)
            nodes.removeValue(forKey: level.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func createLevel(level: NoteChildVM) {
        do {
            let description = NoteLevelDescription(preview: level.preview,
                                                   frame: level.frame,
                                                   id: level.id,
                                                   drawing: PKDrawing(),
                                                   sublevels: [],
                                                   images: [])
            try access.append(level: description, to: id)
            nodes[level.id] = level
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func update(drawing: PKDrawing) {
        do {
            try access.update(drawing: drawing, for: self.id)
            self.drawing = drawing
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func refresh(with image: UIImage) {
        do {
            try access.update(preview: image, for: self.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func moveToDrawer(_ sublevel: NoteChildVM, to frame: CGRect) {
        self.nodes.removeValue(forKey: sublevel.id)
        sublevel.frame = frame
        drawerContents[sublevel.id] = sublevel
    }

    private func moveFromDrawer(_ sublevel: NoteChildVM, to frame: CGRect) {
        self.nodes[sublevel.id] = sublevel
        sublevel.frame = frame
        drawerContents.removeValue(forKey: sublevel.id)
    }

    private func resize(level: NoteChildVM, to frame: CGRect) {
        do {
            try self.access.update(frame: frame, for: level.id)
            level.frame = frame
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func create(image: NoteChildVM) {
        do {
            let description = NoteImageDescription(id: image.id,
                                                   preview: image.preview,
                                                   drawing: PKDrawing(),
                                                   image: image.preview,
                                                   frame: image.frame)
            try self.access.append(image: description, to: id)
            nodes[image.id] = image
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func remove(image: NoteChildVM) {
        do {
            try self.access.remove(image: image.id, from: id)
            nodes.removeValue(forKey: image.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func move(image: NoteChildVM, to frame: CGRect) {
        do {
            try self.access.update(frame: frame, image: image.id)
            nodes[image.id]!.frame = frame
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func resize(image: NoteChildVM, to frame: CGRect) {
        do {
            try self.access.update(frame: frame, image: image.id)
            nodes[image.id]!.frame = frame
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func process(_ command: NoteEditorCommand) {
        switch command {
        case .moveLevel(let level, from: _, to: let destinationFrame):
            self.moveLevel(level: level, to: destinationFrame)

        case .removeLevel(let level):
            self.removeLevel(level: level)

        case .createLevel(let level):
            self.createLevel(level: level)

        case .update(let drawing):
            self.update(drawing: drawing)

        case .refresh(let image):
            self.refresh(with: image)

        case .moveToDrawer(let sublevel, frame: let frame):
            self.moveToDrawer(sublevel, to: frame)

        case .moveFromDrawer(let sublevel, frame: let frame):
            moveFromDrawer(sublevel, to: frame)

        case .resizeLevel(let sublevel, from: _, to: let frame):
            self.resize(level: sublevel, to: frame)

        case .createImage(let image):
            self.create(image: image)

        case .removeImage(let image):
            self.remove(image: image)

        case .moveImage(let image, from: _, to: let frame):
            self.move(image: image, to: frame)

        case .resizeImage(let image, from: _, to: let frame):
            self.resize(image: image, to: frame)
        }
        eventSubject.send(command)
    }
}
