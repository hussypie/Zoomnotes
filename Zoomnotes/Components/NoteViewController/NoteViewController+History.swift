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
                self.undoManager?.registerUndo(withTarget: self) {
                    $0.removeChild(childVM)
                }
                self.undoManager?.setActionName("Create")
                self.logger.info("Undo step for create added")
                return childVM
        }.eraseToAnyPublisher()
    }

    func removeChild(_ sublevel: NoteChildVM) {
        self.viewModel
            .remove(child: sublevel)
            .map {
                self.undoManager?.registerUndo(withTarget: self) {
                    $0.restore(sublevel)
                }
                self.undoManager?.setActionName("Remove")
                self.logger.info("Undo step for remove added")
        }
            .receive(on: DispatchQueue.main)
            .sink(receiveDone: { [unowned self] in
                let preview = self.subLevelViews.first { preview in preview.viewModel?.id == sublevel.id }
                preview?.removeFromSuperview()
                self.subLevelViews.removeAll { preview in preview.viewModel?.id == sublevel.id }
                self.logger.info("Removed child")
                },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot remove child (id: \(sublevel.id)), reason: \(error.localizedDescription)")
                },
                  receiveValue: { }).store(in: &self.cancellables)
    }

    func restore(_ sublevel: NoteChildVM) {
        self.viewModel
            .restore(child: sublevel)
            .map {
                self.undoManager?.registerUndo(withTarget: self) {
                    $0.removeChild(sublevel)
                }
                self.undoManager?.setActionName("Restore")
                self.logger.info("Undo step for restore added")
        }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveDone: { [unowned self] in
                    let preview = self.sublevelPreview(frame: sublevel.frame,
                                                       preview: sublevel.preview)
                    preview.viewModel = sublevel
                    self.canvasView.addSubview(preview)
                    self.logger.info("Restored child")
                },
                receiveError: { [unowned self] error in
                    self.logger.warning("Cannot restore child (id: \(sublevel.id)), reason: \(error.localizedDescription)")
                },
                receiveValue: { }
        ).store(in: &self.cancellables)
    }

    func update(from: PKDrawing, to drawing: PKDrawing) {
        self.viewModel.update(drawing: drawing)
            .sink(receiveDone: { },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot update drawing, reason: \(error.localizedDescription)")
                },
                  receiveValue: {
                    self.undoManager?.registerUndo(withTarget: self) {
                        $0.update(from: drawing, to: from)
                    }
                    self.undoManager?.setActionName("Update Drawing")
            })
            .store(in: &self.cancellables)
    }

    func moveChild(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel
            .move(child: sublevel, to: to)
            .map { [unowned self] in
                self.undoManager?.registerUndo(withTarget: self) {
                    sublevel.frame = from
                    $0.moveChild(sublevel: sublevel, from: to, to: from)
                }
                self.undoManager?.setActionName("Move")
                self.logger.info("Created undo step for move")
        }
            .sink(receiveDone: { },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot move child (id: \(sublevel.id)), reason: \(error.localizedDescription)")
                },
                  receiveValue: { })
            .store(in: &self.cancellables)
    }

    func resizePreview(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel
            .resize(child: sublevel, to: to)
            .sink(receiveDone: { },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot resize preview of child (id: \(sublevel.id)), reason: \(error.localizedDescription)")
                },
                  receiveValue: {
                    self.undoManager?.registerUndo(withTarget: self) {
                        $0.resizePreview(sublevel: sublevel, from: to, to: from)
                    }
                    self.undoManager?.setActionName("Resize")
            })
            .store(in: &self.cancellables)
    }

    func moveToDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel
            .moveToDrawer(child: sublevel, frame: to)
            .sink(receiveDone: { },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot move child (id: \(sublevel.id)) back to canvas, reason: \(error.localizedDescription)")
                },
                  receiveValue: {
                    self.undoManager?.registerUndo(withTarget: self) {
                        $0.moveFromDrawer(sublevel: sublevel, from: to, to: from)
                    }
                    self.undoManager?.setActionName("Move To Drawer")
            })
            .store(in: &self.cancellables)
    }

    func moveFromDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel
            .moveFromDrawer(child: sublevel, frame: to)
            .sink(receiveDone: { },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot move child (id: \(sublevel.id)) back to canvas, reason: \(error.localizedDescription)")
                },
                  receiveValue: {
                    self.undoManager?.registerUndo(withTarget: self) {
                        $0.moveFromDrawer(sublevel: sublevel, from: to, to: from)
                    }
                    self.undoManager?.setActionName("Move To Canvas")
            })
            .store(in: &self.cancellables)
    }
}
