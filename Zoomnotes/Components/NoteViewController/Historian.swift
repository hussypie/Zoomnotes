//
//  NoteViewController+commands.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine
import PencilKit

extension NoteViewController {
    func createImage(id: NoteImageID, frame: CGRect, with preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        return self.viewModel
            .create(id: id, frame: frame, preview: preview)
            .map { childVM in
                self.undoManager?.registerUndo(withTarget: self) { _ in
                    childVM.commander.remove()
                }
                self.undoManager?.setActionName("Add Image")

                return childVM
        }.eraseToAnyPublisher()
    }

    func createLevel(id: NoteLevelID, frame: CGRect, with preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        self.viewModel
            .create(id: id, frame: frame, preview: preview)
            .map { childVM in
                self.undoManager?.registerUndo(withTarget: self) { _ in
                    childVM.commander.remove()
                }
                self.undoManager?.setActionName("Add Sublevel")
                return childVM
        }.eraseToAnyPublisher()
    }

    func removeChild(_ sublevel: NoteChildVM, undo: @escaping (NoteChildVM) -> Void) {
        sublevel.commander.remove()
        self.undoManager?.registerUndo(withTarget: self) { _ in
            sublevel.commander.restore()
            undo(sublevel)
        }
        self.undoManager?.setActionName("Remove")
    }

    func update(from: PKDrawing, to drawing: PKDrawing) {
        self.viewModel.update(drawing: drawing)
        self.undoManager?.registerUndo(withTarget: self) {
            $0.update(from: drawing, to: from)
        }
        self.undoManager?.setActionName("Update Drawing")
    }

    func moveChild(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        UIView.animate(withDuration: 0.15, animations: {
            sublevel.frame = to
        }, completion: { _ in
            sublevel.commander.move(to: to)
            self.undoManager?.registerUndo(withTarget: sublevel) {
                $0.commander.move(to: from)
            }
            self.undoManager?.setActionName("Move Sublevel")
        })
    }

    func resizePreview(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        sublevel.commander.resize(to: to)
        self.undoManager?.registerUndo(withTarget: self) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                sublevel.commander.resize(to: from)
            })
        }
        self.undoManager?.setActionName("Resize")
    }

    func moveToDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        sublevel.commander.moveToDrawer(to: to)
        self.undoManager?.registerUndo(withTarget: self) { _ in
            sublevel.commander.moveFromDrawer(from: from)
        }
        self.undoManager?.setActionName("Move To Drawer")
    }

    func moveFromDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        sublevel.commander.moveFromDrawer(from: from)
        self.undoManager?.registerUndo(withTarget: self) { _ in
            sublevel.commander.moveToDrawer(to: to)
        }
        self.undoManager?.setActionName("Move To Canvas")
    }
}
