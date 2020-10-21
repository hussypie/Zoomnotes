//
//  NoteModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit
import Combine

struct NoteLevelCommander: NoteChildProtocol {
    let id: NoteLevelID
    let editor: NoteEditorViewModel

    func storeEquals(_ id: UUID) -> Bool { self.id == id }

    func detailViewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController? {
        guard let noteViewController = NoteViewController.from(storyboard) else {
                return nil
        }
        return .sublevel(noteViewController, id: id)
    }

    func resize(to: CGRect) {
        editor.resize(id: id, to: to)
    }

    func move(to: CGRect) {
        editor.move(id: id, to: to)
    }

    func remove() {
        editor.remove(id: id)
    }

    func moveToDrawer(to frame: CGRect) {
        editor.moveToDrawer(id: id, frame: frame)
    }

    func moveFromDrawer(from frame: CGRect) {
        editor.moveFromDrawer(id: id, frame: frame)
    }

    func restore() {
        editor.restore(id: id)
    }
}

struct NoteImageCommander: NoteChildProtocol {
    let id: NoteImageID
    let editor: NoteEditorViewModel

    func storeEquals(_ id: UUID) -> Bool { self.id == id }

    func detailViewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController? {
        guard let imageDetailViewController = ImageDetailViewController.from(storyboard) else {
                return nil
        }
        return .image(imageDetailViewController, id: id)
    }

    func resize(to: CGRect) {
        editor.resize(id: id, to: to)
    }

    func move(to: CGRect) {
        editor.move(id: id, to: to)
    }

    func remove() {
        editor.remove(id: id)
    }

    func moveToDrawer(to frame: CGRect) {
        editor.moveToDrawer(id: id, frame: frame)
    }

    func moveFromDrawer(from frame: CGRect) {
        editor.moveFromDrawer(id: id, frame: frame)
    }

    func restore() {
        editor.restore(id: id)
    }
}

class NoteChildVM: ObservableObject {
    let id: UUID
    let commander: NoteChildProtocol
    @Published var preview: UIImage
    @Published var frame: CGRect

    init(id: UUID,
         preview: UIImage,
         frame: CGRect,
         commander: NoteChildProtocol) {
        self.id = id
        self.commander = commander
        self.preview = preview
        self.frame = frame
    }
}
