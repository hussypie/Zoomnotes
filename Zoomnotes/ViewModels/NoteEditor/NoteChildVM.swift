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

    func detailViewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController? {
        guard let noteViewController = NoteViewController.from(storyboard) else {
                return nil
        }
        return .sublevel(noteViewController, id: id)
    }

    func resize(using editor: NoteEditorProtocol, to: CGRect) {
        editor.resize(id: id, to: to)
    }

    func move(using editor: NoteEditorProtocol, to: CGRect) {
        editor.move(id: id, to: to)
    }

    func remove(using editor: NoteEditorProtocol) {
        editor.remove(id: id)
    }
}

struct NoteImageCommander: NoteChildProtocol {
    let id: NoteImageID

    func resize(using editor: NoteEditorProtocol, to: CGRect) {
        editor.resize(id: id, to: to)
    }

    func move(using editor: NoteEditorProtocol, to: CGRect) {
        editor.move(id: id, to: to)
    }

    func remove(using editor: NoteEditorProtocol) {
        editor.remove(id: id)
    }

    func detailViewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController? {
        guard let imageDetailViewController = ImageDetailViewController.from(storyboard) else {
                return nil
        }
        return .image(imageDetailViewController, id: id)
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
