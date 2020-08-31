//
//  NoteViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit

struct ScrollViewState {
    let frame: CGRect
    let contentSize: CGSize
    let contentOffset: CGPoint
}

extension PKCanvasView {
    func saveScrollState() -> ScrollViewState {
        return ScrollViewState(frame: self.frame,
                               contentSize: self.contentSize,
                               contentOffset: self.contentOffset)
    }
    
    func revertToScrollState(_ state: ScrollViewState) {
        self.frame = state.frame
        self.contentSize = state.contentSize
        self.setContentOffset(state.contentOffset, animated: false)
    }
}

class NoteViewController : UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    var toolPicker: PKToolPicker!
    
    var dataModelController: DataModelController!
    var note: NoteModel.NoteLevel!
    var hasModifiedDrawing = false
    
    var subLevelViews: [UUID : NoteLevelPreview] = [:]
    
    // TODO: tool here
    var currentlyDraggedLevel: NoteModel.NoteLevel? = nil
    
    var interactionController: UIPercentDrivenInteractiveTransition? = nil
    
    var drawerView: UIView? = nil
    
    var statusBarHeight: CGFloat {
        self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationController?.delegate = self
        
        canvasView.delegate = self
        canvasView.drawing = note.data.drawing
        canvasView.alwaysBounceVertical = true
        
//        #if targetEnvironment(simulator)
//            canvasView.allowsFingerDrawing = true
//        #else

//        #endif
        canvasView.allowsFingerDrawing = false
        
        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)
        
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        toolPicker.addObserver(self)
        
        updateLayout(for: toolPicker)
        
        canvasView.becomeFirstResponder()
        
        if isMovingToParent || isBeingDismissed {
            for note in note.children.values {
                let sublevel = sublevelPreview(for: note)
                subLevelViews[note.id] = sublevel
                self.canvasView.addSubview(sublevel)
            }
            
            self.view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(onPreviewZoomUp(_:))))
            
            if self.drawerView == nil {
                self.drawerView = DrawerView(in: self.view, title: .constant("Title"))
            }

            self.view.addSubview(drawerView!)
            self.view.bringSubviewToFront(drawerView!)
        }
        
        for note in note.children.values {
            subLevelViews[note.id]?.image = note.previewImage.image
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        let rightEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped(_:)))
        rightEdgeGestureRecognizer.edges = .right
        rightEdgeGestureRecognizer.delegate = self
        
        self.view.addGestureRecognizer(rightEdgeGestureRecognizer)
        
        let leftEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped(_:)))
        leftEdgeGestureRecognizer.edges = .left
        leftEdgeGestureRecognizer.delegate = self
        
        self.view.addGestureRecognizer(leftEdgeGestureRecognizer)
        
        let zoomGestureRecognizer = UIPinchGestureRecognizer(target: self,
                                                             action: #selector(onPinch(_:)))
        self.view.addGestureRecognizer(zoomGestureRecognizer)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasModifiedDrawing {
            updateLevel()
        }
    }
    
    override func viewDidLayoutSubviews() {
        updateContentSizeForDrawing()
        canvasView.contentOffset = CGPoint(x: 0, y: -canvasView.adjustedContentInset.top)
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    override var prefersStatusBarHidden: Bool { false }
    
    @objc func screenEdgeSwiped(_ rec: UIScreenEdgePanGestureRecognizer) {
        let loc = rec.location(in: canvasView)
        let width = self.view.frame.width / 4
        let height = self.view.frame.height / 4
        let frame = CGRect(x: loc.x - width / 2,
                           y: loc.y - height / 2,
                           width: width,
                           height: height)
        
        if rec.state == .changed {
            if currentlyDraggedLevel == nil {
                let defaultPreviewImage = UIImage.from(frame: view.frame).withBackground(color: UIColor.white)
                
                let newLevel = NoteModel.NoteLevel.default(preview: defaultPreviewImage, frame: frame)
                self.addSublevel(sublevel: newLevel)
                
                currentlyDraggedLevel = newLevel
            }
            
            currentlyDraggedLevel!.frame = frame
            subLevelViews[currentlyDraggedLevel!.id]!.frame = frame
        }
        
        if rec.state == .ended {
            subLevelViews[currentlyDraggedLevel!.id]!.frame = frame
            currentlyDraggedLevel!.frame = frame
            currentlyDraggedLevel = nil
        }
    }
    
    @objc func onPinch(_ rec: UIPinchGestureRecognizer) { }
    
    private func addSublevel(sublevel: NoteModel.NoteLevel) {
        hasModifiedDrawing = true
        self.note.children[sublevel.id] = sublevel
        
        let noteLevelPreview = sublevelPreview(for: sublevel)
        self.subLevelViews[sublevel.id] = noteLevelPreview
        
        canvasView.addSubview(noteLevelPreview)
        
        undoManager?.registerUndo(withTarget: self) {
            $0.removeSublevel(sublevel: sublevel)
        }
        self.undoManager?.setActionName("AddSublevel")
    }
    
    private func removeSublevel(sublevel: NoteModel.NoteLevel) {
        hasModifiedDrawing = true
        UIView.animate(withDuration: 0.15, animations: {
            let preview = self.subLevelViews[sublevel.id]!
            preview.frame = CGRect(x: self.canvasView.frame.width,
                                   y: preview.frame.minY,
                                   width: 0,
                                   height: 0)
        }, completion: { _ in
            self.subLevelViews[sublevel.id]!.removeFromSuperview()
            self.note.children.removeValue(forKey: sublevel.id)
        })
        
        self.undoManager?.registerUndo(withTarget: self) {
            $0.addSublevel(sublevel: sublevel)
        }
        self.undoManager?.setActionName("RemoveSublevel")
    }
    
    private func moveSublevel(sublevel: NoteModel.NoteLevel, from: CGRect, to: CGRect) {
        hasModifiedDrawing = true
        UIView.animate(withDuration: 0.15, animations: {
            self.subLevelViews[sublevel.id]!.frame = to
        }, completion: { _ in
            sublevel.frame = to
        })
        
        undoManager?.registerUndo(withTarget: self) {
            $0.moveSublevel(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveSublevel")
    }

    private func onPreviewZoomDown(_ rec: ZNPinchGestureRecognizer, _ note: NoteModel.NoteLevel) {
        let frameInView = CGRect(x: note.frame.minX,
                                 y: note.frame.minY - self.canvasView.contentOffset.y,
                                 width: note.frame.width,
                                 height: note.frame.height)
        let dist = distance(from: view.bounds, to: frameInView)
        let zoomOffset = CGPoint(x: dist.x, y: dist.y - statusBarHeight)
        
        if rec.state == .changed {
            // TODO: Update 4 to calculated value (view width / preview width)
            // needs state
            let scale = clamp(rec.scale, lower: 1, upper: 4)
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
            
            noteViewController.dataModelController = self.dataModelController
            noteViewController.note = note
            navigationController.pushViewController(noteViewController, animated: false)
            self.view.transform = .identity
        }
    }
    
    @objc func onPreviewZoomUp(_ rec: ZNPinchGestureRecognizer) {
        if rec.state == .began {
            self.interactionController = UIPercentDrivenInteractiveTransition()
            navigationController?.popViewController(animated: true)
        }

        if rec.state == .changed {
            let percent = clamp(1 - rec.scale, lower: 0, upper: 1)
            interactionController?.update(percent)
        }

        if rec.state == .ended {
            if rec.scale < 0.5 && rec.state != .cancelled {
                interactionController?.finish()
            } else {
                interactionController?.cancel()
            }
            interactionController = nil
        }
    }
    
    private func updateLevel() {
        note.data.drawing = canvasView.drawing
        let screen = captureCurrentScreen()
        note.previewImage = NoteImage(wrapping: screen)
        dataModelController.updatePreview()
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
    
    private func sublevelPreview(for sublevel: NoteModel.NoteLevel) -> NoteLevelPreview {
        let preview = NoteLevelPreview(for: sublevel)
        
        var originalFrame: CGRect? = nil
        var scrollState: ScrollViewState? = nil
        
        let panGestureRecognizer = ZNPanGestureRecognizer { rec in
            if rec.state == .began {
                originalFrame = preview.frame
                scrollState = self.canvasView.saveScrollState()
                
                let loc = rec.location(in: self.view)
                let rLoc = rec.location(in: preview)
                
                self.view.addSubview(preview)
                
                preview.frame = CGRect(x: loc.x - rLoc.x,
                                       y: loc.y - rLoc.y,
                                       width: preview.frame.width,
                                       height: preview.frame.height)
                
                self.canvasView.bringSubviewToFront(preview)
                
                self.currentlyDraggedLevel = sublevel
            }
            
            let tran = rec.translation(in: self.canvasView)
            let frame = CGRect(x: max(0, preview.frame.minX + tran.x),
                               y: max(0, preview.frame.minY + tran.y),
                                width: preview.frame.width,
                                height: preview.frame.height)
            
            preview.frame = frame
            sublevel.frame = frame
            
            rec.setTranslation(CGPoint.zero, in: self.canvasView)
            
            self.canvasView.revertToScrollState(scrollState!)
            
            if rec.state == .ended {
                // MARK: begin snippet
                /// https://www.raywenderlich.com/1860-uikit-dynamics-and-swift-tutorial-tossing-views
                
                let velocity = rec.velocity(in: self.canvasView)
                let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
                
                let threshold: CGFloat = 5000
                
                if magnitude > threshold {
                    self.fling(velocity, magnitude, sublevel)
                    // MARK: end snippet
                }
                else if self.drawerView!.frame.contains(preview.frame) {
                    let locInDrawer = rec.location(in: self.drawerView)
                    let locInPreview = rec.location(in: preview)
                    
                    preview.removeFromSuperview()
                    self.note.children.removeValue(forKey: self.currentlyDraggedLevel!.id)
                    
                    preview.frame = CGRect(x: locInDrawer.x - locInPreview.x,
                                           y: locInDrawer.y - locInPreview.y,
                                           width: preview.frame.width,
                                           height: preview.frame.height)
                    self.drawerView!.addSubview(preview)
                }
                else {
                    let canvasViewOffset = self.canvasView.contentOffset.y
                    
                    self.canvasView.addSubview(preview)
                    let newFrame = CGRect(x: preview.frame.minX,
                                          y: preview.frame.minY + canvasViewOffset - self.statusBarHeight,
                                            width: preview.frame.width,
                                            height: preview.frame.height)
                    preview.frame = newFrame
                    self.moveSublevel(sublevel: sublevel, from: originalFrame!, to: newFrame)
                }
                
                self.canvasView.revertToScrollState(scrollState!)
                
                originalFrame = nil
                scrollState = nil
                self.currentlyDraggedLevel = nil
            }
        }
        
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        
        preview.addGestureRecognizer(panGestureRecognizer)
        
        preview.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:))))
        
        preview.addGestureRecognizer(ZNPinchGestureRecognizer { rec in
            self.onPreviewZoomDown(rec, sublevel)
        })
        
        return preview
    }
    
    private func updateContentSizeForDrawing() {
        // Update the content size to match the drawing.
        let drawing = canvasView.drawing
        let contentHeight: CGFloat
        
        // Adjust the content size to always be bigger than the drawing height.
        if !drawing.bounds.isNull {
            contentHeight = max(canvasView.bounds.height, (drawing.bounds.maxY * 1.5) * canvasView.zoomScale)
        } else {
            contentHeight = canvasView.bounds.height
        }
        canvasView.contentSize = CGSize(width: view.frame.width * canvasView.zoomScale, height: contentHeight)
    }
    
    private func captureCurrentScreen() -> UIImage {
        drawerView!.alpha = 0.0
        defer {
            drawerView!.alpha = 1.0
        }
        UIGraphicsBeginImageContext(view.frame.size)
        let context = UIGraphicsGetCurrentContext()!
        view.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    private func setNewDrawingUndoable(_ newDrawing: PKDrawing) {
        let oldDrawing = canvasView.drawing
        undoManager?.registerUndo(withTarget: self) {
            $0.setNewDrawingUndoable(oldDrawing)
        }
        canvasView.drawing = newDrawing
    }
    
    func updateLayout(for toolPicker: PKToolPicker) {
        let obscuredFrame = toolPicker.frameObscured(in: view)
        
        if obscuredFrame.isNull {
            canvasView.contentInset = .zero
            navigationItem.rightBarButtonItems = []
        } else {
            canvasView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.maxY - obscuredFrame.minY, right: 0)
            navigationItem.rightBarButtonItems = [undoButton, redoButton]
        }
        
        canvasView.scrollIndicatorInsets = canvasView.contentInset
    }
}

extension NoteViewController : PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        hasModifiedDrawing = true
        updateContentSizeForDrawing()
    }
    
    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
    
    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
}

extension NoteViewController : PKToolPickerObserver {
    
}
