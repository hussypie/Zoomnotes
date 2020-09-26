//
//  NoteViewController+sublevel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension NoteViewController {
    func onPreviewZoomDown(_ rec: ZNPinchGestureRecognizer, _ note: NoteLevelVM) {
        let frameInView = CGRect(x: note.frame.minX,
                                 y: note.frame.minY - self.canvasView.contentOffset.y,
                                 width: note.frame.width,
                                 height: note.frame.height)
        let dist = distance(from: view.bounds, to: frameInView)
        let zoomOffset = CGPoint(x: dist.x, y: dist.y - statusBarHeight)

        let ratio = view.bounds.width / note.frame.width

        if rec.state == .changed {
            let scale = clamp(rec.scale, lower: 1, upper: ratio)
            view.transform = zoomDownTransform(at: scale, for: zoomOffset)
        }

        if rec.state == .ended {
            guard rec.scale > 2 else {
                UIView.animate(withDuration: 0.1) {
                    self.view.transform = .identity
                }
                return
            }

            guard let noteViewController = storyboard?.instantiateViewController(withIdentifier: String(describing: NoteViewController.self)) as? NoteViewController,
                let navigationController = navigationController else {
                    return
            }

            noteViewController.viewModel = self.viewModel.childViewModel(for: note)
            navigationController.pushViewController(noteViewController, animated: false)
            self.view.transform = .identity
        }
    }

    private enum MoveOrigin {
        case drawer
        case canvas
    }

    private struct PanGestureState {
        let originalFrame: CGRect
        let dragging: NoteLevelPreview
        let origin: MoveOrigin
    }

    private func panGestureBegin(_ rec: UIPanGestureRecognizer, _ preview: NoteLevelPreview) -> PanGestureState {
        let origin: MoveOrigin
        if preview.superview! == self.drawerView! {
            origin = .drawer
        } else {
            origin = .canvas
        }

        let loc = rec.location(in: self.view)
        let rLoc = rec.location(in: preview)

        self.view.addSubview(preview)

        preview.frame = CGRect(x: loc.x - rLoc.x,
                               y: loc.y - rLoc.y,
                               width: preview.frame.width,
                               height: preview.frame.height)

        self.canvasView.bringSubviewToFront(preview)
        return PanGestureState(originalFrame: preview.frame, dragging: preview, origin: origin)
    }

    private func panGestureStep(_ rec: UIPanGestureRecognizer, state: PanGestureState) -> PanGestureState {
        let tran = rec.translation(in: self.canvasView)
        let frame = CGRect(x: max(0, state.dragging.frame.minX + tran.x),
                           y: max(0, state.dragging.frame.minY + tran.y),
                           width: state.dragging.frame.width,
                           height: state.dragging.frame.height)

        state.dragging.frame = frame

        rec.setTranslation(CGPoint.zero, in: self.canvasView)
        return state
    }

    private func panGestureEnded(_ rec: UIPanGestureRecognizer, state: PanGestureState, sublevel: NoteLevelVM) {
        // MARK: begin snippet
        /// https://www.raywenderlich.com/1860-uikit-dynamics-and-swift-tutorial-tossing-views

        let velocity = rec.velocity(in: self.canvasView)
        let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))

        let catapult = Catapult(threshold: 4000, in: self.view) {
            self.removeSublevel(sublevel)
        }

        if catapult.tryFling(velocity, magnitude, state.dragging) { return }

        if self.drawerView.frame.contains(state.dragging.frame) {
            let locInDrawer = rec.location(in: self.drawerView)
            let locInPreview = rec.location(in: state.dragging)
            let frameInDrawer = CGRect(x: locInDrawer.x - locInPreview.x,
                                       y: locInDrawer.y - locInPreview.y,
                                       width: state.dragging.frame.width,
                                       height: state.dragging.frame.height)

            let originalFrame = state.originalFrame
            if state.origin == .canvas {
                self.moveToDrawer(sublevel: sublevel,
                                  from: originalFrame,
                                  to: frameInDrawer)
            } else {
                self.moveSublevel(sublevel: sublevel, from: originalFrame, to: frameInDrawer)
            }
        } else {
            let canvasViewOffset = self.canvasView.contentOffset.y
            let newFrame = CGRect(x: state.dragging.frame.minX,
                                  y: state.dragging.frame.minY + canvasViewOffset - self.statusBarHeight,
                                  width: state.dragging.frame.width,
                                  height: state.dragging.frame.height)

            let originalFrame = state.originalFrame

            if state.origin == .drawer {
                self.moveFromDrawer(sublevel: sublevel, from: originalFrame, to: newFrame)
            } else {
                self.moveSublevel(sublevel: sublevel, from: originalFrame, to: newFrame)
            }
        }
    }

    private func panGesture(for sublevel: NoteLevelVM, _ preview: NoteLevelPreview) -> ZNPanGestureRecognizer<PanGestureState> {
        return ZNPanGestureRecognizer<PanGestureState>(
            begin: { rec in return self.panGestureBegin(rec, preview) },
            step: self.panGestureStep(_:state:),
            end: { rec, state in self.panGestureEnded(rec, state: state, sublevel: sublevel) }
        )
    }

    private struct CloneGestureState {
        let originalFrame: CGRect
        let dragging: NoteLevelPreview
    }

    private func cloneGesture(for sublevel: NoteLevelVM) -> ZNPanGestureRecognizer<CloneGestureState> {
        ZNPanGestureRecognizer<CloneGestureState>(
            begin: { rec in
                let newPreview = self.sublevelPreview(for: sublevel)
                self.canvasView.addSubview(newPreview)
                return CloneGestureState(originalFrame: sublevel.frame,
                                         dragging: newPreview)
        },
            step: { rec, state in
                let tran = rec.translation(in: self.canvasView)
                let frame = CGRect(x: max(0, state.dragging.frame.minX + tran.x),
                                   y: max(0, state.dragging.frame.minY + tran.y),
                                   width: state.dragging.frame.width,
                                   height: state.dragging.frame.height)

                state.dragging.frame = frame

                rec.setTranslation(CGPoint.zero, in: self.canvasView)
                return state
        },
            end: { _, state in
                let copiedSublevel = NoteLevelVM(id: UUID(),
                                                 preview: sublevel.preview,
                                                 frame: sublevel.frame)

                self.addSublevel(copiedSublevel)
                state.dragging.removeFromSuperview()

        })
    }

    func sublevelPreview(for sublevel: NoteLevelVM) -> NoteLevelPreview {
        let preview = NoteLevelPreview(
            frame: sublevel.frame,
            preview: sublevel.preview,
            resizeEnded: { self.resizePreview(sublevel: sublevel, from: sublevel.frame, to: $0) }
        )

        preview.copyIndicator.addGestureRecognizer(cloneGesture(for: sublevel))

        preview.addGestureRecognizer(panGesture(for: sublevel, preview))

        preview.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomUp($0) })

        preview.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomDown($0, sublevel) })

        preview.addGestureRecognizer(ZNTapGestureRecognizer { rec in
            let location = rec.location(in: preview)
            preview.setEdited(in: preview.bounds.half(of: location))
        }.taps(2))

        return preview
    }
}
