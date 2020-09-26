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
    let note: NoteModel
    let level: NoteModel.NoteLevel

    @Published var noteTitle: String
    @Published var sublevels: [UUID: NoteModel.NoteLevel]
    @Published var drawing: PKDrawing

    @Published var drawerContents: [UUID: NoteModel.NoteLevel]

    let eventSubject = PassthroughSubject<NoteEditorCommand, Never>()
    private let access: NoteLevelAccess

    private var cancellables: Set<AnyCancellable> = []

    init(note: NoteModel, level: NoteModel.NoteLevel, access: NoteLevelAccess) {
        self.note = note
        self.level = level

        self.noteTitle = note.title
        self.sublevels = level.children
        self.drawing = level.data.drawing

        self.drawerContents = [:]

        self.access = access

        self.$sublevels
            .sink(receiveValue: { level.children = $0 })
            .store(in: &cancellables)
    }

    private convenience init(note: NoteModel,
                             level: NoteModel.NoteLevel,
                             drawer: [UUID: NoteModel.NoteLevel],
                             access: NoteLevelAccess
    ) {
        self.init(note: note,
                  level: level,
                  access: access)
        self.drawerContents = drawer
    }

    func childViewModel(for level: NoteModel.NoteLevel) -> NoteEditorViewModel {
        return NoteEditorViewModel(note: self.note,
                                   level: level,
                                   drawer: self.drawerContents,
                                   access: self.access)
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
                                                       preview: level.previewImage.image.pngData()!,
                                                       frame: level.frame,
                                                       id: UUID(),
                                                       drawing: PKDrawing())
                try access.create(from: description)
                sublevels[level.id] = level
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .update(let drawing):
            do {
                try access.update(drawing: drawing, for: level.id)
                level.data.drawing = drawing
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .refresh(let image):
            do {
                try access.update(preview: image, for: level.id)
                level.previewImage = image
            } catch let error {
                fatalError(error.localizedDescription)
            }

        case .moveToDrawer(let sublevel, frame: let frame):
            self.level.children.removeValue(forKey: sublevel.id)
            sublevel.frame = frame
            drawerContents[sublevel.id] = sublevel

        case .moveFromDrawer(let sublevel, frame: let frame):
            self.level.children[sublevel.id] = sublevel
            sublevel.frame = frame
            drawerContents.removeValue(forKey: sublevel.id)

        case .resize(let sublevel, from: _, to: let frame):
            sublevel.frame = frame
        }
        eventSubject.send(command)
    }
}
