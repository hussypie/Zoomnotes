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

class NoteEditorViewModel: ObservableObject, NoteEditorProtocol {
    @Published var title: String
    @Published var drawing: PKDrawing

    private let id: NoteLevelID
    private let access: NoteLevelAccess
    private let onUpdateName: (String) -> Void
    private let sublevels: [NoteChildVM]

    private var cancellables: Set<AnyCancellable> = []

    init(id: NoteLevelID,
         title: String,
         sublevels: [NoteChildVM],
         drawing: PKDrawing,
         access: NoteLevelAccess,
         onUpdateName: @escaping (String) -> Void
    ) {
        self.id = id
        self.title = title
        self.drawing = drawing
        self.sublevels = sublevels

        self.onUpdateName = onUpdateName

        self.access = access

        self.$title
            .sink { self.onUpdateName($0) }
            .store(in: &cancellables)
    }

    func load(_ use: (NoteChildVM) -> Void) {
        for sublevel in self.sublevels {
            use(sublevel)
        }
    }

    func childViewModel(for id: NoteLevelID) -> NoteEditorViewModel? {
        guard let subLevel = try? self.access.read(level: id) else { return nil }
        let subSubLevels = subLevel.sublevels
            .map { NoteChildVM(id: UUID(),
                               preview: $0.preview,
                               frame: $0.frame,
                               commander: NoteLevelCommander(id: $0.id)) }

        let subSubImages = subLevel.images
            .map { NoteChildVM(id: UUID(),
                               preview: $0.preview,
                               frame: $0.frame,
                               commander: NoteImageCommander(id: $0.id)) }

        return NoteEditorViewModel(id: id,
                                   title: self.title,
                                   sublevels: subSubLevels + subSubImages,
                                   drawing: subLevel.drawing,
                                   access: self.access,
                                   onUpdateName: self.onUpdateName)
    }

    func imageDetailViewModel(for id: NoteImageID) -> ImageDetailViewModel? {
        guard let subimage = try? self.access.read(image: id) else { return nil }
        return ImageDetailViewModel(using: subimage.image, with: subimage.drawing)
    }

    func create(id: NoteLevelID, frame: CGRect, preview: UIImage) {
        do {
            let description = NoteLevelDescription(preview: preview,
                                                   frame: frame,
                                                   id: id,
                                                   drawing: PKDrawing(),
                                                   sublevels: [],
                                                   images: [])
            try access.append(level: description, to: self.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func create(id: NoteImageID, frame: CGRect, preview: UIImage) {
        do {
            let description = NoteImageDescription(id: id,
                                                   preview: preview,
                                                   drawing: PKDrawing(),
                                                   image: preview,
                                                   frame: frame)
            try self.access.append(image: description, to: self.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func update(drawing: PKDrawing) {
        do {
            try access.update(drawing: drawing, for: self.id)
            self.drawing = drawing
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func update(id: NoteImageID, annotation: PKDrawing) {
        do {
            try access.update(annotation: annotation, image: id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func update(id: NoteImageID, preview: UIImage) {
        do {
            try access.update(preview: preview, image: id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func refresh(image: UIImage) {
        do {
            try access.update(preview: image, for: self.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func move(id: NoteLevelID, to: CGRect) {
        do {
            try access.update(frame: to, for: id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func move(id: NoteImageID, to: CGRect) {
        do {
            try self.access.update(frame: to, image: id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func resize(id: NoteLevelID, to frame: CGRect) {
        do {
            try self.access.update(frame: frame, for: id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func remove(id: NoteLevelID) {
        do {
            try self.access.remove(level: id, from: self.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func remove(id: NoteImageID) {
        do {
            try self.access.remove(image: id, from: self.id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func resize(id: NoteImageID, to: CGRect) {
        do {
            try self.access.update(frame: to, image: id)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    func moveToDrawer(id: NoteImageID, frame: CGRect) {
        fatalError("Not implemented")
    }

    func moveFromDrawer(id: NoteImageID, frame: CGRect) {
        fatalError("Not implemented")
    }

    func moveToDrawer(id: NoteLevelID, frame: CGRect) {
        fatalError("Not implemented")
    }

    func moveFromDrawer(id: NoteLevelID, frame: CGRect) {
        fatalError("Not implemented")
    }
}
