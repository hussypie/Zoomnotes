//
//  NoteViewController+commands.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

extension NoteViewController {
    func addChild(_ sublevel: NoteChildVM) {
        self.viewModel.process(sublevel.commander.create(sublevel))

        undoManager?.registerUndo(withTarget: self) {
            $0.removeChild(sublevel)
        }
        self.undoManager?.setActionName("AddSublevel")
    }

    func removeChild(_ sublevel: NoteChildVM) {
        UIView.animate(withDuration: 0.15, animations: {
            let preview = self.subLevelViews[sublevel.id]!
            preview.frame = CGRect(x: self.canvasView.frame.width,
                                   y: preview.frame.minY,
                                   width: 0,
                                   height: 0)
        }, completion: { _ in
            self.viewModel.process(sublevel.commander.remove(sublevel))
            self.undoManager?.registerUndo(withTarget: self) {
                $0.addChild(sublevel)
            }
            self.undoManager?.setActionName("RemoveSublevel")
        })
    }

    func moveChild(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        UIView.animate(withDuration: 0.15, animations: {
            self.subLevelViews[sublevel.id]!.frame = to
        }, completion: { _ in
            self.viewModel.process(sublevel.commander.move(sublevel, to: to))
            self.undoManager?.registerUndo(withTarget: self) {
                $0.moveChild(sublevel: sublevel, from: to, to: from)
            }
            self.undoManager?.setActionName("MoveSublevel")
        })
    }

    func moveToDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        // TODO: generalize to images
        self.viewModel.process(.moveToDrawer(sublevel, frame: to))
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveFromDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveToDrawer")
    }

    func moveFromDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        // TODO: generalize to images
        self.viewModel.process(.moveFromDrawer(sublevel, frame: to))
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveToDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveFromDrawer")
    }

    func resizePreview(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        // TODO: generalize to images
        self.viewModel.process(.resizeLevel(sublevel, from: sublevel.frame, to: to))
        self.undoManager?.registerUndo(withTarget: self) { sself in
            UIView.animate(withDuration: 0.1, animations: {
                sself.resizePreview(sublevel: sublevel, from: to, to: from)
            })
        }
        self.undoManager?.setActionName("ResizePreview")
    }

    func setNewDrawingUndoable(_ newDrawing: PKDrawing) {
        let oldDrawing = canvasView.drawing
        self.viewModel.process(.update(newDrawing))
        undoManager?.registerUndo(withTarget: self) {
            $0.setNewDrawingUndoable(oldDrawing)
        }
        undoManager?.setActionName("UpdateDrawing")
    }

    func onCommand(_ command: NoteEditorCommand) {
        switch command {
        case .createLevel(let sublevel):
            let noteLevelPreview = sublevelPreview(for: sublevel)
            self.subLevelViews[sublevel.id] = noteLevelPreview
            self.canvasView.addSubview(noteLevelPreview)
            self.view.bringSubviewToFront(noteLevelPreview)

        case .removeLevel(let sublevel):
            self.subLevelViews[sublevel.id]!.removeFromSuperview()
            self.subLevelViews.removeValue(forKey: sublevel.id)

        case .moveToDrawer(let sublevel, frame: let frame):
            let preview = subLevelViews[sublevel.id]!
            preview.removeFromSuperview()

            subLevelViews.removeValue(forKey: sublevel.id)
            self.drawerView!.contents[sublevel.id] = preview
            self.drawerView!.addSubview(preview)
            preview.frame = frame

        case .moveFromDrawer(let sublevel, frame: let frame):
            let preview = self.drawerView!.contents[sublevel.id]!
            preview.removeFromSuperview()

            self.drawerView!.contents.removeValue(forKey: sublevel.id)
            self.view.addSubview(preview)
            self.subLevelViews[sublevel.id] = preview
            preview.frame = frame
        case .resizeLevel:
            return

        case .createImage(let vm):
            let noteLevelPreview = sublevelPreview(for: vm)
            self.subLevelViews[vm.id] = noteLevelPreview
            self.canvasView.addSubview(noteLevelPreview)
            self.view.bringSubviewToFront(noteLevelPreview)

        case .moveImage:
            return
        case .resizeImage:
            return
        case .removeImage:
            return
        case .moveLevel:
            return
        case .update:
            return
        case .refresh:
            return
        case .updateAnnotation(id: let id, with: let with):
            return
        case .updatePreview(id: let id, with: let with):
            return
        }
    }
}
