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
    @Published var sublevels: [UUID: NoteLevelVM]
    @Published var drawing: PKDrawing
    @Published var drawerContents: [UUID: NoteLevelVM]

    private let id: UUID
    private let access: NoteLevelAccess
    private let onUpdateName: (String) -> Void

    let eventSubject = PassthroughSubject<NoteEditorCommand, Never>()
    private var cancellables: Set<AnyCancellable> = []

    init(id: UUID,
         title: String,
         sublevels: [UUID: NoteLevelVM],
         drawing: PKDrawing,
         access: NoteLevelAccess,
         drawer: [UUID: NoteLevelVM],
         onUpdateName: @escaping (String) -> Void
    ) {
        self.id = id
        self.title = title
        self.sublevels = sublevels
        self.drawing = drawing

        self.onUpdateName = onUpdateName
        self.drawerContents = drawer

        self.access = access

        self.$title
            .sink { self.onUpdateName($0) }
            .store(in: &cancellables)
    }

    func childViewModel(for level: NoteLevelVM) -> NoteEditorViewModel? {
        guard let subLevel = try? self.access.read(level: level.id) else { return nil }
        let subSubLevels = subLevel.sublevels
            .map { NoteLevelVM(id: $0.id,
                                                                preview: UIImage(data: $0.preview)!,
                                                                frame: $0.frame) }
            .map { ($0.id, $0) }
        return NoteEditorViewModel(id: level.id,
                                   title: self.title,
                                   sublevels: Dictionary.init(uniqueKeysWithValues: subSubLevels),
                                   drawing: subLevel.drawing,
                                   access: self.access,
                                   drawer: self.drawerContents,
                                   onUpdateName: self.onUpdateName)
    }

    func process(_ command: NoteEditorCommand) {
        switch command {
        case .move(let level, from: _, to: let destinationFrame):
            do {
                try access.update(frame: destinationFrame, for: level.id)
                sublevels[level.id]!.frame = destinationFrame
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .remove(let level):
            do {
                try access.delete(level: level.id)
                sublevels.removeValue(forKey: level.id)
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .create(let level):
            do {
                let description = NoteLevelDescription(parent: level.id,
                                                       preview: level.preview.pngData()!,
                                                       frame: level.frame,
                                                       id: UUID(),
                                                       drawing: PKDrawing(),
                                                       sublevels: [])
                try access.create(from: description)
                sublevels[level.id] = level
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .update(let drawing):
            do {
                try access.update(drawing: drawing, for: self.id)
                self.drawing = drawing
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .refresh(let image):
            do {
                try access.update(preview: image, for: self.id)
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .moveToDrawer(let sublevel, frame: let frame):
            self.sublevels.removeValue(forKey: sublevel.id)
            sublevel.frame = frame
            drawerContents[sublevel.id] = sublevel

        case .moveFromDrawer(let sublevel, frame: let frame):
            self.sublevels[sublevel.id] = sublevel
            sublevel.frame = frame
            drawerContents.removeValue(forKey: sublevel.id)

        case .resize(let sublevel, from: _, to: let frame):
            sublevel.frame = frame
        }
        eventSubject.send(command)
    }
}
