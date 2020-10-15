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

    func childViewModel(for id: NoteLevelID) -> AnyPublisher<NoteEditorViewModel?, Error> {
        return access.read(level: id)
            .map { subLevel in
                    guard let subLevel = subLevel else { return nil }

                    let subSubLevels =
                        subLevel.sublevels
                            .map { NoteChildVM(id: UUID(),
                                               preview: $0.preview,
                                               frame: $0.frame,
                                               commander: NoteLevelCommander(id: $0.id)) }

                    let subSubImages =
                        subLevel.images
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
        }.eraseToAnyPublisher()
    }

    func imageDetailViewModel(for id: NoteImageID) -> AnyPublisher<ImageDetailViewModel?, Error> {
        access.read(image: id)
            .map { subimage in
                        guard let subimage = subimage else { return nil }
                        return ImageDetailViewModel(using: subimage.image, with: subimage.drawing)
        }.eraseToAnyPublisher()
    }

    func create(id: NoteLevelID, frame: CGRect, preview: UIImage) {
        let description = NoteLevelDescription(preview: preview,
                                               frame: frame,
                                               id: id,
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        access.append(level: description, to: self.id)
            .sink(receiveCompletion: { error in fatalError("\(error)") },
                  receiveValue: { })
            .store(in: &cancellables)
    }

    func create(id: NoteImageID, frame: CGRect, preview: UIImage) {
        let description = NoteImageDescription(id: id,
                                               preview: preview,
                                               drawing: PKDrawing(),
                                               image: preview,
                                               frame: frame)
        access.append(image: description, to: self.id)
            .sink(receiveCompletion: { error in fatalError("\(error)") },
                  receiveValue: { })
            .store(in: &cancellables)

    }

    func update(drawing: PKDrawing) {
        access.update(drawing: drawing, for: self.id)
            .sink(receiveCompletion: { error in fatalError("\(error)") },
                  receiveValue: { self.drawing = drawing })
            .store(in: &cancellables)
    }

    func update(id: NoteImageID, annotation: PKDrawing) {
        access.update(annotation: annotation, image: id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                      receiveValue: { })
            .store(in: &cancellables)
    }

    func update(id: NoteImageID, preview: UIImage) {
        access.update(preview: preview, image: id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)

    }

    func refresh(image: UIImage) {
        access.update(preview: image, for: self.id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)
    }

    func move(id: NoteLevelID, to: CGRect) {
        access.update(frame: to, for: id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)

    }

    func move(id: NoteImageID, to: CGRect) {
        access.update(frame: to, image: id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)
    }

    func resize(id: NoteLevelID, to frame: CGRect) {
        access.update(frame: frame, for: id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)

    }

    func remove(id: NoteLevelID) {
        self.access.remove(level: id, from: self.id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)
    }

    func remove(id: NoteImageID) {
        access.remove(image: id, from: self.id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)
    }

    func resize(id: NoteImageID, to: CGRect) {
        access.update(frame: to, image: id)
            .sink(receiveCompletion: { error in fatalError("\(error)")},
                  receiveValue: { })
            .store(in: &cancellables)
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
