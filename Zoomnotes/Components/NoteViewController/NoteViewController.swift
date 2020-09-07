//
//  NoteViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit
import Combine

struct DragState {
    let currentlyDraggedLevel: NoteModel.NoteLevel
    let originalFrame: CGRect
}

class NoteViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!

    var toolPicker: PKToolPicker!

    var viewModel: NoteEditorViewModel!

    var dragState: DragState? = nil

    var hasModifiedDrawing = false

    var subLevelViews: [UUID: NoteLevelPreview] = [:]

    var interactionController: UIPercentDrivenInteractiveTransition? = nil

    var drawerView: DrawerView!

    private var cancellables: Set<AnyCancellable> = []

    private var statusBarHeight: CGFloat {
        self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }

    private func edgeGestureRecognizer(edge: UIRectEdge) -> UIScreenEdgePanGestureRecognizer {
        let edgeGestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped(_:)))
        edgeGestureRecognizer.edges = edge
        edgeGestureRecognizer.delegate = self
        #if targetEnvironment(simulator)
        #else
        edgeGestureRecognizer.allowedTouchTypes = [ UITouch.TouchType.pencil ]
        #endif
        return edgeGestureRecognizer
    }

    private func setup(_ canvasView: PKCanvasView) {
        canvasView.delegate = self
        canvasView.drawing = viewModel.drawing
        canvasView.alwaysBounceVertical = true

        #if targetEnvironment(simulator)
        canvasView.allowsFingerDrawing = true
        #else
        canvasView.allowsFingerDrawing = false
        #endif

        canvasView.becomeFirstResponder()
    }

    private func setup(_ toolPicker: PKToolPicker) {
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        toolPicker.addObserver(self)

        updateLayout(for: toolPicker)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationController?.delegate = self

        setup(canvasView)

        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)
        setup(toolPicker)

        for note in viewModel.sublevels.values {
            subLevelViews[note.id]?.image = note.previewImage.image
        }

        if self.drawerView != nil {
            self.drawerView.removeFromSuperview()
        }
        self.drawerView = DrawerView(in: self.view, title: .constant("Title"))
        for level in self.viewModel.drawerContents.values {
            let preview = sublevelPreview(for: level)
            self.drawerView.contents[level.id] = preview
            self.drawerView.addSubview(preview)
            self.drawerView.bringSubviewToFront(preview)
        }

        self.view.addSubview(drawerView!)
        self.view.bringSubviewToFront(drawerView!)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        let edges: [UIRectEdge] = [.left, .right]

        edges.forEach { self.view.addGestureRecognizer(edgeGestureRecognizer(edge: $0)) }

        for note in viewModel.sublevels.values {
            let sublevel = sublevelPreview(for: note)
            subLevelViews[note.id] = sublevel
            self.canvasView.addSubview(sublevel)
        }

        self.view.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomUp($0) })

        viewModel.eventSubject
            .sink(receiveValue: { self.onCommand($0) })
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateDrawingMeta),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateDrawingMeta),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasModifiedDrawing {
            self.updateDrawingMeta()
        }
    }

    override func viewDidLayoutSubviews() {
        updateContentSizeForDrawing()
        canvasView.contentOffset = CGPoint(x: 0, y: -canvasView.adjustedContentInset.top)
    }

    @objc func screenEdgeSwiped(_ rec: UIScreenEdgePanGestureRecognizer) {
        let loc = rec.location(in: canvasView)
        let width = self.view.frame.width / 4
        let height = self.view.frame.height / 4
        let frame = CGRect(x: loc.x - width / 2,
                           y: loc.y - height / 2,
                           width: width,
                           height: height)

        if rec.state == .changed {
            if dragState == nil {
                let defaultPreviewImage = UIImage.from(frame: view.frame).withBackground(color: UIColor.white)

                let newLevel = NoteModel.NoteLevel.default(preview: defaultPreviewImage, frame: frame)
                self.addSublevel(sublevel: newLevel)

                dragState = DragState(currentlyDraggedLevel: newLevel, originalFrame: frame)
            }

            dragState!.currentlyDraggedLevel.frame = frame
            subLevelViews[dragState!.currentlyDraggedLevel.id]!.frame = frame
        }

        if rec.state == .ended {
            subLevelViews[dragState!.currentlyDraggedLevel.id]!.frame = frame
            dragState!.currentlyDraggedLevel.frame = frame
            dragState = nil
        }
    }

    @objc func onPinch(_ rec: UIPinchGestureRecognizer) { }

    @objc private func updateDrawingMeta() {
        let screen = captureCurrentScreen()
        self.viewModel.process(.refresh(NoteImage(wrapping: screen)))
    }

    private func addSublevel(sublevel: NoteModel.NoteLevel) {
        self.viewModel.process(.create(sublevel))

        undoManager?.registerUndo(withTarget: self) {
            $0.removeSublevel(sublevel: sublevel)
        }
        self.undoManager?.setActionName("AddSublevel")
    }

    private func removeSublevel(sublevel: NoteModel.NoteLevel) {
        UIView.animate(withDuration: 0.15, animations: {
            let preview = self.subLevelViews[sublevel.id]!
            preview.frame = CGRect(x: self.canvasView.frame.width,
                                   y: preview.frame.minY,
                                   width: 0,
                                   height: 0)
        }, completion: { _ in
            self.viewModel.process(.remove(sublevel))
            self.undoManager?.registerUndo(withTarget: self) {
                $0.addSublevel(sublevel: sublevel)
            }
            self.undoManager?.setActionName("RemoveSublevel")
        })
    }

    private func moveSublevel(sublevel: NoteModel.NoteLevel, from: CGRect, to: CGRect) {
        UIView.animate(withDuration: 0.15, animations: {
            self.subLevelViews[sublevel.id]!.frame = to
        }, completion: { _ in
            self.undoManager?.registerUndo(withTarget: self) {
                $0.moveSublevel(sublevel: sublevel, from: to, to: from)
            }
            self.undoManager?.setActionName("MoveSublevel")
        })
    }

    private func moveToDrawer(sublevel: NoteModel.NoteLevel, from: CGRect, to: CGRect) {
        self.viewModel.process(.moveToDrawer(sublevel, frame: to))
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveFromDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveToDrawer")
    }

    private func moveFromDrawer(sublevel: NoteModel.NoteLevel, from: CGRect, to: CGRect) {
        self.viewModel.process(.moveFromDrawer(sublevel, frame: to))
        self.undoManager?.registerUndo(withTarget: self) {
            $0.moveToDrawer(sublevel: sublevel, from: to, to: from)
        }
        self.undoManager?.setActionName("MoveFromDrawer")
    }

    private func onCommand(_ command: NoteEditorCommand) {
        self.hasModifiedDrawing = true

        switch command {
        case .create(let sublevel):
            let noteLevelPreview = sublevelPreview(for: sublevel)
            self.subLevelViews[sublevel.id] = noteLevelPreview
            canvasView.addSubview(noteLevelPreview)

        case .remove(let sublevel):
            self.subLevelViews[sublevel.id]!.removeFromSuperview()

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

        default:
            return
        }
    }

    private func onPreviewZoomDown(_ rec: ZNPinchGestureRecognizer, _ note: NoteModel.NoteLevel) {
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

    private func onPreviewZoomUp(_ rec: ZNPinchGestureRecognizer) {
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

    private func panGesture(for sublevel: NoteModel.NoteLevel, _ preview: NoteLevelPreview) -> UIPanGestureRecognizer {
        var origin: MoveOrigin = .drawer
        return ZNPanGestureRecognizer { rec in
            if rec.state == .began {
                if preview.superview! == self.drawerView! {
                    origin = .drawer
                } else {
                    origin = .canvas
                }

                self.dragState = DragState(currentlyDraggedLevel: sublevel, originalFrame: preview.frame)

                let loc = rec.location(in: self.view)
                let rLoc = rec.location(in: preview)

                self.view.addSubview(preview)

                preview.frame = CGRect(x: loc.x - rLoc.x,
                                       y: loc.y - rLoc.y,
                                       width: preview.frame.width,
                                       height: preview.frame.height)

                self.canvasView.bringSubviewToFront(preview)
            }

            let tran = rec.translation(in: self.canvasView)
            let frame = CGRect(x: max(0, preview.frame.minX + tran.x),
                               y: max(0, preview.frame.minY + tran.y),
                               width: preview.frame.width,
                               height: preview.frame.height)

            preview.frame = frame
            sublevel.frame = frame

            rec.setTranslation(CGPoint.zero, in: self.canvasView)

            if rec.state == .ended {
                // MARK: begin snippet
                /// https://www.raywenderlich.com/1860-uikit-dynamics-and-swift-tutorial-tossing-views

                let velocity = rec.velocity(in: self.canvasView)
                let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))

                let threshold: CGFloat = 4000

                if magnitude > threshold {
                    self.fling(velocity, magnitude, sublevel)
                    // MARK: end snippet
                } else if self.drawerView.frame.contains(preview.frame) {
                    let locInDrawer = rec.location(in: self.drawerView)
                    let locInPreview = rec.location(in: preview)
                    let frameInDrawer = CGRect(x: locInDrawer.x - locInPreview.x,
                                               y: locInDrawer.y - locInPreview.y,
                                               width: preview.frame.width,
                                               height: preview.frame.height)

                    let originalFrame = self.dragState!.originalFrame
                    if origin == .canvas {
                        self.moveToDrawer(sublevel: sublevel,
                                          from: originalFrame,
                                          to: frameInDrawer)
                    } else {
                        self.moveSublevel(sublevel: sublevel, from: originalFrame, to: frameInDrawer)
                    }
                } else {
                    let canvasViewOffset = self.canvasView.contentOffset.y
                    let newFrame = CGRect(x: preview.frame.minX,
                                          y: preview.frame.minY + canvasViewOffset - self.statusBarHeight,
                                          width: preview.frame.width,
                                          height: preview.frame.height)

                    let originalFrame = self.dragState!.originalFrame

                    if origin == .drawer {
                        self.moveFromDrawer(sublevel: sublevel, from: originalFrame, to: newFrame)
                    } else {
                        self.moveSublevel(sublevel: sublevel, from: originalFrame, to: newFrame)
                    }
                }

                self.dragState = nil
            }
        }.touches(1)
    }

    private func sublevelPreview(for sublevel: NoteModel.NoteLevel) -> NoteLevelPreview {
        let preview = NoteLevelPreview(frame: sublevel.frame, resizeEnded: { frame in
            self.viewModel.process(.resize(sublevel, from: sublevel.frame, to: frame))
        }, copyStarted: { })

        preview.addGestureRecognizer(panGesture(for: sublevel, preview))

        preview.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomUp($0) })

        preview.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomDown($0, sublevel) })

        preview.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            preview.isEdited.toggle()
        }.taps(2))

        return preview
    }

    private func updateContentSizeForDrawing() {
        let drawing = canvasView.drawing
        let contentHeight: CGFloat

        if !drawing.bounds.isNull {
            contentHeight = max(canvasView.bounds.height, (drawing.bounds.maxY * 1.5) * canvasView.zoomScale)
        } else {
            contentHeight = canvasView.bounds.height
        }
        canvasView.contentSize = CGSize(width: view.frame.width * canvasView.zoomScale, height: contentHeight)
    }

    private func captureCurrentScreen() -> UIImage {
        drawerView.alpha = 0.0
        defer {
            drawerView.alpha = 1.0
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

extension NoteViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        self.viewModel.process(.update(canvasView.drawing))
        updateContentSizeForDrawing()
    }

    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }

    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
}

extension NoteViewController: PKToolPickerObserver { }
