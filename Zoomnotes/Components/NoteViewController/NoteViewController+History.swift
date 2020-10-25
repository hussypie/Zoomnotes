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
    func create(id: NoteChildStore, frame: CGRect, with preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        return self.viewModel
            .create(id: id, frame: frame, preview: preview)
            .map { childVM in
                self.undoManager?.registerUndo(withTarget: self) { _ in
                    self.viewModel.remove(child: childVM)
                }
                switch id {
                case .level:
                    self.undoManager?.setActionName("Add Level")
                case .image:
                    self.undoManager?.setActionName("Add Image")
                }
                return childVM
        }.eraseToAnyPublisher()
    }


    func removeChild(_ sublevel: NoteChildVM, undo: @escaping (NoteChildVM) -> Void) {
        self.viewModel.remove(child: sublevel)
        self.undoManager?.registerUndo(withTarget: self) { _ in
            self.viewModel.restore(child: sublevel)
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
            self.viewModel.move(child: sublevel, to: to)
        }, completion: { _ in
            self.undoManager?.registerUndo(withTarget: self) {
                $0.moveChild(sublevel: sublevel, from: to, to: from)
            }
            self.undoManager?.setActionName("Move Sublevel")
        })
    }

    func resizePreview(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel.resize(child: sublevel, to: to)
        self.undoManager?.registerUndo(withTarget: self) {
            $0.resizePreview(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("Resize")
    }

    func moveToDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel.moveToDrawer(child: sublevel, frame: to)
        self.undoManager?.registerUndo(withTarget: self) { _ in
            self.moveFromDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("Move To Drawer")
    }

    func moveFromDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel.moveToDrawer(child: sublevel, frame: to)
        self.undoManager?.registerUndo(withTarget: self) { _ in
            self.moveToDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("Move To Canvas")
    }
}
