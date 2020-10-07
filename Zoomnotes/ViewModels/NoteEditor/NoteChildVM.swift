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

enum NoteChildDetailViewController {
    case image(ImageDetailViewController)
    case sublevel(NoteViewController)
}

protocol NoteChildCommandable {
    func create(_ vm: NoteChildVM) -> NoteEditorCommand
    func resize(_ vm: NoteChildVM, to: CGRect) -> NoteEditorCommand
    func move(_ vm: NoteChildVM, to: CGRect) -> NoteEditorCommand
    func remove(_ vm: NoteChildVM) -> NoteEditorCommand
    func viewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController?
}

struct NoteLevelCommander: NoteChildCommandable {
    func viewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController? {
        guard let noteViewController = NoteViewController.from(storyboard) else {
                return nil
        }
        return .sublevel(noteViewController)
    }

    func create(_ vm: NoteChildVM) -> NoteEditorCommand {
        return .createLevel(vm)
    }

    func resize(_ vm: NoteChildVM, to: CGRect) -> NoteEditorCommand {
        return .resizeLevel(vm, from: vm.frame, to: to)
    }

    func move(_ vm: NoteChildVM, to: CGRect) -> NoteEditorCommand {
        return .moveLevel(vm, from: vm.frame, to: to)
    }

    func remove(_ vm: NoteChildVM) -> NoteEditorCommand {
        return .removeLevel(vm)
    }
}

struct NoteImageCommander: NoteChildCommandable {
    func create(_ vm: NoteChildVM) -> NoteEditorCommand {
        return .createImage(vm)
    }

    func resize(_ vm: NoteChildVM, to: CGRect) -> NoteEditorCommand {
        return .resizeImage(vm, from: vm.frame, to: to)
    }

    func move(_ vm: NoteChildVM, to: CGRect) -> NoteEditorCommand {
        return .moveImage(vm, from: vm.frame, to: to)
    }

    func remove(_ vm: NoteChildVM) -> NoteEditorCommand {
        return .removeImage(vm)
    }

    func viewController(from storyboard: UIStoryboard?) -> NoteChildDetailViewController? {
        guard let imageDetailViewController = ImageDetailViewController.from(storyboard) else {
                return nil
        }
        return .image(imageDetailViewController)
    }
}

class NoteChildVM: ObservableObject {
    let id: UUID
    let commander: NoteChildCommandable
    @Published var preview: UIImage
    @Published var frame: CGRect

    init(id: UUID,
         preview: UIImage,
         frame: CGRect,
         commander: NoteChildCommandable) {
        self.id = id
        self.commander = commander
        self.preview = preview
        self.frame = frame
    }
}
