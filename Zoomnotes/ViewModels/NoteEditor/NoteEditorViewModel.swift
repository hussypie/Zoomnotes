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

    private func `switch`(
        id: NoteChildStore,
        level: (NoteLevelID) -> AnyPublisher<Void, Error>,
        image: (NoteImageID) -> AnyPublisher<Void, Error>
    ) -> AnyPublisher<Void, Error> {
        switch id {
        case .level(let lid):
            return level(lid)
        case .image(let iid):
            return image(iid)
        }
    }

    func move(child: NoteChildVM, to: CGRect) -> AnyPublisher<Void, Error> {
        `switch`(
            id: child.store,
            level: { [unowned self] lid in self.move(id: lid, to: to) },
            image: { [unowned self] iid in self.move(id: id, to: to) }
        ).map { child.frame = to }
        .eraseToAnyPublisher()
    }

    func resize(child: NoteChildVM, to: CGRect) -> AnyPublisher<Void, Error> {
        `switch`(
            id: child.store,
            level: { [unowned self] id in self.resize(id: id, to: to) },
            image: { [unowned self] id in self.resize(id: id, to: to) }
        ).map { child.frame = to }
        .eraseToAnyPublisher()
    }

    func remove(child: NoteChildVM) -> AnyPublisher<Void, Error> {
        `switch`(
            id: child.store,
            level: { [unowned self] id in self.remove(id: id) },
            image: { [unowned self] id in self.remove(id: id) }
        ).map { [unowned self] in self.nodes = self.nodes.filter { $0.id != child.id } }
        .eraseToAnyPublisher()
    }

    func restore(child: NoteChildVM) -> AnyPublisher<Void, Error> {
        `switch`(
            id: child.store,
            level: { [unowned self] id in self.restore(id: id) },
            image: { [unowned self] id in self.restore(id: id) }
        ).map { [unowned self] in self.nodes.append(child) }
        .eraseToAnyPublisher()
    }

    func moveToDrawer(child: NoteChildVM, frame: CGRect) -> AnyPublisher<Void, Error> {
        `switch`(
            id: child.store,
            level: { [unowned self] id in self.moveToDrawer(id: id, frame: frame) },
            image: { [unowned self] id in self.moveToDrawer(id: id, frame: frame) }
        ).map { [unowned self] in
            self.nodes.append(child)
            self.nodes = self.nodes.filter { $0.id != child.id }
            self.drawer.nodes.append(child)
            child.frame = frame
        }
        .eraseToAnyPublisher()
    }

    func moveFromDrawer(child: NoteChildVM, frame: CGRect) -> AnyPublisher<Void, Error> {
        `switch`(
            id: child.store,
            level: { [unowned self] id in self.moveFromDrawer(id: id, frame: frame) },
            image: { [unowned self] id in self.moveFromDrawer(id: id, frame: frame) }
        ).map { [unowned self] _ in
            self.drawer.nodes = self.drawer.nodes.filter { $0.id != child.id }
            self.nodes.append(child)
            child.frame = frame
        }.eraseToAnyPublisher()
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

    func update(drawing: PKDrawing) -> AnyPublisher<Void, Error> {
        access.update(drawing: drawing, for: self.id)
    }

    func update(id: NoteImageID, annotation: PKDrawing) -> AnyPublisher<Void, Error> {
        access.update(annotation: annotation, image: id)
    }

    func update(id: NoteImageID, preview: UIImage) -> AnyPublisher<Void, Error> {
        access.update(preview: preview, image: id)
    }

    func refresh(image: UIImage) -> AnyPublisher<Void, Error> {
        access.update(preview: image, for: self.id)
    }

    private func move(id: NoteLevelID, to: CGRect) -> AnyPublisher<Void, Error> {
        access.update(frame: to, for: id)
    }

    private func move(id: NoteImageID, to: CGRect) -> AnyPublisher<Void, Error> {
        access.update(frame: to, image: id)
    }

    private func resize(id: NoteLevelID, to frame: CGRect) -> AnyPublisher<Void, Error> {
        access.update(frame: frame, for: id)
    }

    private func remove(id: NoteLevelID) -> AnyPublisher<Void, Error> {
        self.access.remove(level: id, from: self.id)
    }

    private func remove(id: NoteImageID) -> AnyPublisher<Void, Error> {
        access.remove(image: id, from: self.id)
    }

    private func restore(id: NoteImageID) -> AnyPublisher<Void, Error> {
        let iid = id
        return access
            .restore(image: iid, to: self.id)
            .map { _ in return }
            .eraseToAnyPublisher()
    }

    private func restore(id: NoteLevelID) -> AnyPublisher<Void, Error> {
        let iid = id
        return access
            .restore(level: iid, to: self.id)
            .map { _ in return }
            .eraseToAnyPublisher()
    }

    private func resize(id: NoteImageID, to: CGRect) -> AnyPublisher<Void, Error> {
        access.update(frame: to, image: id)
    }

    private func moveToDrawer(id: NoteImageID, frame: CGRect) -> AnyPublisher<Void, Error> {
        let iid = id
        return access
            .moveToDrawer(image: iid, from: self.id)
            .flatMap { [unowned self] _ in self.access.update(frame: frame, image: iid) }
            .eraseToAnyPublisher()
    }

    private func moveFromDrawer(id: NoteImageID, frame: CGRect) -> AnyPublisher<Void, Error> {
        let iid = id
        return access
            .moveFromDrawer(image: iid, to: self.id)
            .flatMap { [unowned self] _ in self.access.update(frame: frame, image: iid) }
            .eraseToAnyPublisher()
    }

    private func moveToDrawer(id: NoteLevelID, frame: CGRect) -> AnyPublisher<Void, Error> {
        let iid = id
        return access
            .moveToDrawer(level: iid, from: self.id)
            .flatMap { [unowned self] _ in self.access.update(frame: frame, for: iid) }
            .eraseToAnyPublisher()
    }

    private func moveFromDrawer(id: NoteLevelID, frame: CGRect) -> AnyPublisher<Void, Error> {
        let iid = id
        return access
            .moveFromDrawer(level: iid, to: self.id)
            .flatMap { [unowned self] _ in self.access.update(frame: frame, for: iid) }
            .eraseToAnyPublisher()
    }
}
