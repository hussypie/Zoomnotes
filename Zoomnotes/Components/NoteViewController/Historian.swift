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

class Historian {
    private let undoManager: UndoManager?
    private let viewModel: NoteEditorViewModel

    init(undoManager: UndoManager?, viewModel: NoteEditorViewModel) {
        self.undoManager = undoManager
        self.viewModel = viewModel
    }

    func createImage(id: NoteImageID, frame: CGRect, with preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        return self.viewModel
            .create(id: id, frame: frame, preview: preview)
            .map { _ in
                let childVM = NoteChildVM(id: UUID(),
                                          preview: preview,
                                          frame: frame,
                                          commander: NoteImageCommander(id: id))

                self.undoManager?.registerUndo(withTarget: self) {
                    childVM.commander.remove(using: $0.viewModel)
                }
                self.undoManager?.setActionName("AddSubimage")

                return childVM
        }.eraseToAnyPublisher()
    }

    func createLevel(id: NoteLevelID, frame: CGRect, with preview: UIImage) -> AnyPublisher<NoteChildVM, Error> {
        self.viewModel
            .create(id: id, frame: frame, preview: preview)
            .map { _ in
                let childVM = NoteChildVM(id: UUID(),
                                            preview: preview,
                                            frame: frame,
                                            commander: NoteLevelCommander(id: id))

                self.undoManager?.registerUndo(withTarget: self) {
                    childVM.commander.remove(using: $0.viewModel)
                }
                self.undoManager?.setActionName("AddSubimage")
                return childVM
        }.eraseToAnyPublisher()
    }

    func removeChild(_ sublevel: NoteChildVM, undo: @escaping (NoteChildVM) -> Void) {
        UIView.animate(withDuration: 0.15, animations: {
            sublevel.frame = CGRect(x: -sublevel.frame.width,
                                   y: -sublevel.frame.height,
                                   width: 0,
                                   height: 0)
        }, completion: { _ in
            sublevel.commander.remove(using: self.viewModel)
            self.undoManager?.registerUndo(withTarget: self) { _ in
                undo(sublevel)
            }
            self.undoManager?.setActionName("RemoveSublevel")
        })
    }

    func moveChild(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        UIView.animate(withDuration: 0.15, animations: {
            sublevel.frame = to
        }, completion: { _ in
            sublevel.commander.move(using: self.viewModel, to: to)
            self.undoManager?.registerUndo(withTarget: self) {
                $0.moveChild(sublevel: sublevel, from: to, to: from)
            }
            self.undoManager?.setActionName("MoveSublevel")
        })
    }

    func moveToDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        fatalError("Not implemented")
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveFromDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveToDrawer")
    }

    func moveFromDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        fatalError("Not implemented")
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveToDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveFromDrawer")
    }

    func resizePreview(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        sublevel.commander.resize(using: self.viewModel, to: to)
        self.undoManager?.registerUndo(withTarget: self) { sself in
            UIView.animate(withDuration: 0.1, animations: {
                sself.resizePreview(sublevel: sublevel, from: to, to: from)
            })
        }
        self.undoManager?.setActionName("ResizePreview")
    }
}
