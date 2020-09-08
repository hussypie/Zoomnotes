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
    func onPreviewZoomDown(_ rec: ZNPinchGestureRecognizer, _ note: NoteModel.NoteLevel) {
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

    private func fling(_ velocity: CGPoint, _ magnitude: CGFloat, _ sublevel: NoteModel.NoteLevel) {
        let velocityPadding: CGFloat  = 35
        let preview = subLevelViews[sublevel.id]!
        let animator = UIDynamicAnimator(referenceView: self.view)
        let pushBehavior = UIPushBehavior(items: [preview], mode: .instantaneous)
        pushBehavior.pushDirection = CGVector(dx: velocity.x / 10, dy: velocity.y / 10)
        pushBehavior.magnitude = magnitude / velocityPadding

        animator.addBehavior(pushBehavior)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            animator.removeAllBehaviors()

            self.removeSublevel(sublevel: sublevel)
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

    private func panGestureEnded(_ rec: UIPanGestureRecognizer, state: PanGestureState, sublevel: NoteModel.NoteLevel) {
        // MARK: begin snippet
        /// https://www.raywenderlich.com/1860-uikit-dynamics-and-swift-tutorial-tossing-views

        let velocity = rec.velocity(in: self.canvasView)
        let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))

        let threshold: CGFloat = 4000

        if magnitude > threshold {
            self.fling(velocity, magnitude, sublevel)
            // MARK: end snippet
        } else if self.drawerView.frame.contains(state.dragging.frame) {
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

    private func panGesture(for sublevel: NoteModel.NoteLevel, _ preview: NoteLevelPreview) -> UIPanGestureRecognizer {
        return ZNPanGestureRecognizer<PanGestureState>(
            begin: { rec in return self.panGestureBegin(rec, preview) },
            step: self.panGestureStep(_:state:),
            end: { rec, state in self.panGestureEnded(rec, state: state, sublevel: sublevel)}
        )
    }

    func sublevelPreview(for sublevel: NoteModel.NoteLevel) -> NoteLevelPreview {
        let preview = NoteLevelPreview(frame: sublevel.frame,
                                       preview: sublevel.previewImage.image,
                                       resizeEnded: { frame in
                                        self.resizePreview(sublevel: sublevel, from: sublevel.frame, to: frame)
        }, copyStarted: {
            let newFrame = CGRect(x: sublevel.frame.minX + 100,
                                  y: sublevel.frame.minY,
                                  width: sublevel.frame.width,
                                  height: sublevel.frame.height)
            let copiedSublevel = NoteModel.NoteLevel(data: sublevel.data,
                                                     children: sublevel.children,
                                                     preview: sublevel.previewImage.image,
                                                     frame: newFrame)
            self.addSublevel(sublevel: copiedSublevel)
        })

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
