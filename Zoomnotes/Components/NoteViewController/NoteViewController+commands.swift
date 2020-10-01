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
    func addSublevel(_ sublevel: NoteChildVM) {
        self.viewModel.process(.createLevel(sublevel))

        undoManager?.registerUndo(withTarget: self) {
            $0.removeSublevel(sublevel)
        }
        self.undoManager?.setActionName("AddSublevel")
    }

    func removeSublevel(_ sublevel: NoteChildVM) {
        UIView.animate(withDuration: 0.15, animations: {
            let preview = self.subLevelViews[sublevel.id]!
            preview.frame = CGRect(x: self.canvasView.frame.width,
                                   y: preview.frame.minY,
                                   width: 0,
                                   height: 0)
        }, completion: { _ in
            self.viewModel.process(.removeLevel(sublevel))
            self.undoManager?.registerUndo(withTarget: self) {
                $0.addSublevel(sublevel)
            }
            self.undoManager?.setActionName("RemoveSublevel")
        })
    }

    func moveSublevel(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        UIView.animate(withDuration: 0.15, animations: {
            self.subLevelViews[sublevel.id]!.frame = to
        }, completion: { _ in
            self.undoManager?.registerUndo(withTarget: self) {
                $0.moveSublevel(sublevel: sublevel, from: to, to: from)
            }
            self.undoManager?.setActionName("MoveSublevel")
        })
    }

    func moveToDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel.process(.moveToDrawer(sublevel, frame: to))
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveFromDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveToDrawer")
    }

    func moveFromDrawer(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
        self.viewModel.process(.moveFromDrawer(sublevel, frame: to))
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveToDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveFromDrawer")
    }

    func resizePreview(sublevel: NoteChildVM, from: CGRect, to: CGRect) {
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
        self.hasModifiedDrawing = true

        switch command {
        case .createLevel(let sublevel):
            let noteLevelPreview = sublevelPreview(for: sublevel)
            noteLevelPreview.alpha = 0.0
            self.subLevelViews[sublevel.id] = noteLevelPreview
            UIView.animate(withDuration: 0.1) {
                noteLevelPreview.alpha = 1.0
                self.canvasView.addSubview(noteLevelPreview)
                self.view.bringSubviewToFront(noteLevelPreview)
            }

        case .removeLevel(let sublevel):
            self.subLevelViews[sublevel.id]!.removeFromSuperview()
            self.subLevelViews.removeValue(forKey: sublevel.id)

        case .moveToDrawer(let sublevel, frame: let frame):
            let preview = subLevelViews[sublevel.id]!
            preview.removeFromSuperview()

            subLevelViews.removeValue(forKey: sublevel.id)
            self.drawerView.contents[sublevel.id] = preview
            self.drawerView.addSubview(preview)
            preview.frame = frame

        case .moveFromDrawer(let sublevel, frame: let frame):
            let preview = self.drawerView.contents[sublevel.id]!
            preview.removeFromSuperview()

            self.drawerView.contents.removeValue(forKey: sublevel.id)
            self.view.addSubview(preview)
            self.subLevelViews[sublevel.id] = preview
            preview.frame = frame
        case .resizeLevel(let sublevel, from: _, to: let frame):
            let preview = self.subLevelViews[sublevel.id]!
            preview.setFrame(to: frame)

        case .createImage:
            return

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
        }
    }
}
