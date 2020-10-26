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
    @Published var nodes: [NoteChildVM] = []

    let drawer: DrawerVM

    private let id: NoteLevelID
    private let access: NoteLevelAccess
    private let onUpdateName: (String) -> Void

    private var cancellables: Set<AnyCancellable> = []

    init(id: NoteLevelID,
         title: String,
         sublevels: [NoteChildVM],
         drawer: DrawerVM,
         drawing: PKDrawing,
         access: NoteLevelAccess,
         onUpdateName: @escaping (String) -> Void
    ) {
        self.id = id
        self.title = title
        self.drawing = drawing
        self.onUpdateName = onUpdateName

        self.access = access

        self.nodes = sublevels

        self.drawer = drawer

        self.$title
            .sink { self.onUpdateName($0) }
            .store(in: &cancellables)
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
                                           store: .level($0.id)) }

                let subSubImages =
                    subLevel.images
                        .map { NoteChildVM(id: UUID(),
                                           preview: $0.preview,
                                           frame: $0.frame,
                                           store: .image($0.id)) }

                return NoteEditorViewModel(id: id,
                                           title: self.title,
                                           sublevels: subSubLevels + subSubImages,
                                           drawer: self.drawer,
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

    func create(id: NoteChildStore, frame: CGRect, preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        switch id {
        case .level(let lid):
            return self.create(id: lid, frame: frame, preview: preview)
        case .image(let iid):
            return self.create(id: iid, frame: frame, preview: preview)

        }
    }

    func move(child: NoteChildVM, to: CGRect) {
        switch child.store {
        case .level(let lid):
            self.move(id: lid, to: to)
        case .image(let iid):
            self.move(id: iid, to: to)

        }
        child.frame = to
    }

    func resize(child: NoteChildVM, to: CGRect) {
        switch child.store {
        case .level(let id):
            self.resize(id: id, to: to)
        case .image(let id):
            self.resize(id: id, to: to)
        }
        child.frame = to
    }

    func remove(child: NoteChildVM) {
        switch child.store {
        case .level(let id):
            self.remove(id: id)
        case .image(let id):
            self.remove(id: id)
        }
        self.nodes = self.nodes.filter { $0.id != child.id }
    }

    func restore(child: NoteChildVM) {
        switch child.store {
        case .level(let id):
            self.restore(id: id)
        case .image(let id):
            self.restore(id: id)
        }
        self.nodes.append(child)
    }

    func moveToDrawer(child: NoteChildVM, frame: CGRect) {
        switch child.store {
        case .level(let id):
            self.moveToDrawer(id: id, frame: frame)
        case .image(let id):
            self.moveToDrawer(id: id, frame: frame)
        }
        self.nodes = self.nodes.filter { $0.id != child.id }
        self.drawer.nodes.append(child)
        child.frame = frame
    }

    func moveFromDrawer(child: NoteChildVM, frame: CGRect) {
        switch child.store {
        case .level(let id):
            self.moveFromDrawer(id: id, frame: frame)
        case .image(let id):
            self.moveFromDrawer(id: id, frame: frame)
        }
        self.drawer.nodes = self.drawer.nodes.filter { $0.id != child.id }
        self.nodes.append(child)
        child.frame = frame
    }

    private func create(id: NoteLevelID, frame: CGRect, preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        let description = NoteLevelDescription(preview: preview,
                                               frame: frame,
                                               id: id,
                                               drawing: PKDrawing(),
                                               sublevels: [],
                                               images: [])

        return access
            .append(level: description, to: self.id)
            .map {
                let child = NoteChildVM(id: UUID(),
                                        preview: preview,
                                        frame: frame,
                                        store: .level(id))
                self.nodes.append(child)
                return child
        }.eraseToAnyPublisher()
    }

    private func create(id: NoteImageID, frame: CGRect, preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        let description = NoteImageDescription(id: id,
                                               preview: preview,
                                               drawing: PKDrawing(),
                                               image: preview,
                                               frame: frame)
        return access
            .append(image: description, to: self.id)
            .map {
                let child = NoteChildVM(id: UUID(),
                                        preview: preview,
                                        frame: frame,
                                        store: .image(id))
                self.nodes.append(child)
                return child
        }.eraseToAnyPublisher()
    }

    func update(drawing: PKDrawing) {
        access.update(drawing: drawing, for: self.id)
            .sink(receiveCompletion: { _ in /* TODO logging */  },
                  receiveValue: { self.drawing = drawing })
            .store(in: &cancellables)
    }

    func update(id: NoteImageID, annotation: PKDrawing) {
        access.update(annotation: annotation, image: id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)
    }

    func update(id: NoteImageID, preview: UIImage) {
        access.update(preview: preview, image: id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)

    }

    func refresh(image: UIImage) {
        access.update(preview: image, for: self.id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func move(id: NoteLevelID, to: CGRect) {
        access.update(frame: to, for: id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)

    }

    private func move(id: NoteImageID, to: CGRect) {
        access.update(frame: to, image: id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func resize(id: NoteLevelID, to frame: CGRect) {
        access.update(frame: frame, for: id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)

    }

    private func remove(id: NoteLevelID) {
        self.access.remove(level: id, from: self.id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func remove(id: NoteImageID) {
        access.remove(image: id, from: self.id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func restore(id: NoteImageID) {
        let iid = id
        access.restore(image: iid, to: self.id)
            .sink(receiveDone: { /* TODO logging */ },
               receiveError: { _ in /* TODO logging */ },
               receiveValue: { _ in /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func restore(id: NoteLevelID) {
        let iid = id
        access.restore(level: iid, to: self.id)
            .sink(receiveDone: { /* TODO logging */ },
               receiveError: { _ in /* TODO logging */ },
               receiveValue: { _ in /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func resize(id: NoteImageID, to: CGRect) {
        access.update(frame: to, image: id)
            .sink(receiveCompletion: { _ in /* TODO logging */ },
                  receiveValue: { /* TODO logging */ })
            .store(in: &cancellables)
    }

    private func moveToDrawer(id: NoteImageID, frame: CGRect) {
        let iid = id
        access
            .moveToDrawer(image: iid, from: self.id)
            .flatMap { _ in
                self.access.update(frame: frame, image: iid)
        }.sink(receiveDone: { /* TODO logging */ },
               receiveError: { _ in /* TODO logging */ },
               receiveValue: { _ in /* TODO logging */ })
        .store(in: &cancellables)
    }

    private func moveFromDrawer(id: NoteImageID, frame: CGRect) {
        let iid = id
        access
            .moveFromDrawer(image: iid, to: self.id)
            .flatMap { _ in
                self.access.update(frame: frame, image: iid)
        }.sink(receiveDone: { /* TODO logging */ },
               receiveError: { _ in /* TODO logging */ },
               receiveValue: { _ in  /* TODO logging */ })
        .store(in: &cancellables)
    }

    private func moveToDrawer(id: NoteLevelID, frame: CGRect) {
        let iid = id
        access
            .moveToDrawer(level: iid, from: self.id)
            .flatMap { _ in
                self.access.update(frame: frame, for: iid)
        }.sink(receiveDone: { /* TODO logging */ },
               receiveError: { _ in /* TODO logging */ },
               receiveValue: { _ in  /* TODO logging */ })
        .store(in: &cancellables)
    }

    private func moveFromDrawer(id: NoteLevelID, frame: CGRect) {
        let iid = id
        access
            .moveFromDrawer(level: iid, to: self.id)
            .flatMap { _ in
                self.access.update(frame: frame, for: iid)
        }.sink(receiveDone: { /* TODO logging */ },
               receiveError: { _ in /* TODO logging */ },
               receiveValue: { _ in  /* TODO logging */ })
        .store(in: &cancellables)
    }
}
