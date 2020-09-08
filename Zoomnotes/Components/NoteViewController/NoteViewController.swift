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
    var drawerView: DrawerView!
    var toolPicker: PKToolPicker!

    var viewModel: NoteEditorViewModel!

    var hasModifiedDrawing = false

    var subLevelViews: [UUID: NoteLevelPreview] = [:]

    var interactionController: UIPercentDrivenInteractiveTransition? = nil

    private var cancellables: Set<AnyCancellable> = []

    var statusBarHeight: CGFloat {
        self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }

    private struct EdgePanGestureState {
        let sublevel: NoteModel.NoteLevel
        let currentlyDraggedPreview: NoteLevelPreview
    }

    private func edgeGestureRecognizer(edge: UIRectEdge) -> ZNScreenEdgePanGesture<EdgePanGestureState> {
        let edgeGestureRecognizer = ZNScreenEdgePanGesture<EdgePanGestureState>(
            begin: { rec in
                let frame = self.defaultPreviewFrame(from: rec.location(in: self.canvasView))

                let defaultPreviewImage = UIImage.from(frame: self.view.frame).withBackground(color: UIColor.white)
                let newLevel = NoteModel.NoteLevel.default(preview: defaultPreviewImage, frame: frame)

                let newLevelPreview = self.sublevelPreview(for: newLevel)
                self.view.addSubview(newLevelPreview)

                return EdgePanGestureState(sublevel: newLevel,
                                           currentlyDraggedPreview: newLevelPreview)
        },
            step: { rec, state in
                let translation = rec.translation(in: self.view)
                let oldFrame = state.currentlyDraggedPreview.frame
                state.currentlyDraggedPreview.frame = CGRect(x: oldFrame.minX + translation.x,
                                                             y: oldFrame.minY + translation.y,
                                                             width: oldFrame.width,
                                                             height: oldFrame.height)
                rec.setTranslation(CGPoint.zero, in: self.view)
                return state
        },
            end: { rec, state in
                let velocity = rec.velocity(in: self.canvasView)
                let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))

                let catapult = Catapult(threshold: 4000, in: self.view) { }

                if catapult.tryFling(velocity, magnitude, state.currentlyDraggedPreview) { return }
                state.sublevel.frame = state.currentlyDraggedPreview.frame
                state.currentlyDraggedPreview.removeFromSuperview()
                self.addSublevel(state.sublevel)
        })
        edgeGestureRecognizer.edges = edge
        edgeGestureRecognizer.delegate = self
        #if targetEnvironment(simulator)
        #else
        edgeGestureRecognizer.allowedTouchTypes = [ UITouch.TouchType.pencil ]
        #endif
        return edgeGestureRecognizer
    }

    private func defaultPreviewFrame(from loc: CGPoint) -> CGRect {
        let width = self.view.frame.width / 4
        let height = self.view.frame.height / 4
        let frame = CGRect(x: loc.x - width / 2,
                           y: loc.y - height / 2,
                           width: width,
                           height: height)
        return frame
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

        NSLayoutConstraint.activate([
            self.drawerView!.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.drawerView!.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.drawerView!.heightAnchor.constraint(equalTo: self.view.heightAnchor,
                                                     constant: -2 * self.view.frame.height / 3)
        ])
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

    @objc func onPinch(_ rec: UIPinchGestureRecognizer) { }

    @objc private func updateDrawingMeta() {
        let screen = captureCurrentScreen()
        self.viewModel.process(.refresh(NoteImage(wrapping: screen)))
    }

    func onPreviewZoomUp(_ rec: ZNPinchGestureRecognizer) {
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
