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

enum NoteEditorCommand {
    case move(NoteModel.NoteLevel, from: CGRect, to: CGRect)
    case remove(NoteModel.NoteLevel)
    case create(NoteModel.NoteLevel)
    case resize(NoteModel.NoteLevel, from: CGRect, to: CGRect)
    case update(PKDrawing)
    case refresh(CodableImage)
    case moveToDrawer(NoteModel.NoteLevel, frame: CGRect)
    case moveFromDrawer(NoteModel.NoteLevel, frame: CGRect)
}

class NoteEditorViewModel: ObservableObject {
    let note: NoteModel
    let level: NoteModel.NoteLevel
    let dataModelController: DataModelController

    @Published var noteTitle: String
    @Published var sublevels: [UUID: NoteModel.NoteLevel]
    @Published var drawing: PKDrawing

    @Published var drawerContents: [UUID: NoteModel.NoteLevel]

    var eventSubject = PassthroughSubject<NoteEditorCommand, Never>()

    private var cancellables: Set<AnyCancellable> = []

    init(note: NoteModel, level: NoteModel.NoteLevel, dataModelController: DataModelController) {
        self.note = note
        self.level = level
        self.dataModelController = dataModelController

        self.noteTitle = note.title
        self.sublevels = level.children
        self.drawing = level.data.drawing

        self.drawerContents = [:]

        self.$sublevels
            .sink(receiveValue: { level.children = $0 })
            .store(in: &cancellables)
    }

    private convenience init(note: NoteModel,
                             level: NoteModel.NoteLevel,
                             dataModelController: DataModelController,
                             drawer: [UUID: NoteModel.NoteLevel]
    ) {
        self.init(note: note,
                  level: level,
                  dataModelController: dataModelController)
        self.drawerContents = drawer
    }

    func childViewModel(for level: NoteModel.NoteLevel) -> NoteEditorViewModel {
        return NoteEditorViewModel(note: self.note,
                                   level: level,
                                   dataModelController: self.dataModelController,
                                   drawer: self.drawerContents)
    }

    func process(_ command: NoteEditorCommand) {
        switch command {
        case .move(let level, from: _, to: let destinationFrame):
            sublevels[level.id]!.frame = destinationFrame

        case .remove(let level):
            sublevels.removeValue(forKey: level.id)

        case .create(let level):
            sublevels[level.id] = level

        case .update(let drawing):
            level.data.drawing = drawing

        case .refresh(let image):
            level.previewImage = image
            dataModelController.updatePreview()

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
