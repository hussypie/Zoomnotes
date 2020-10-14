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
import SwiftUI
import SnapKit

struct DragState {
    let currentlyDraggedLevel: NoteChildVM
    let originalFrame: CGRect
}

class NoteViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!

    var drawerView: DrawerView? = nil
    private var imagePicker: UIHostingController<ImagePickerDrawer>? = nil

    fileprivate var toolPicker: PKToolPicker!
    var transitionManager: NoteTransitionDelegate!

    var viewModel: NoteEditorViewModel!
    var historian: Historian!

    private var drawerViewTopOffset: Constraint!

    var subLevelViews: [UUID: NoteLevelPreview] = [:]

    var interactionController: UIPercentDrivenInteractiveTransition? = nil

    private(set) var previewChangedSubject = PassthroughSubject<UIImage, Never>()

    fileprivate var cancellables: Set<AnyCancellable> = []

    var statusBarHeight: CGFloat {
        self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }

    private lazy var drawerViewPanGesture: ZNPanGestureRecognizer<Void> = {
        return ZNPanGestureRecognizer(
            begin: { _ in },
            step: { [unowned self] rec, _ in
                let touchHeight = rec.location(in: self.view).y
                let offset = clamp(self.view.frame.height - touchHeight,
                                   lower: 50,
                                   upper: self.view.frame.height / 3)
                self.drawerViewTopOffset.update(offset: -offset)
            },
            end: { _, _ in }
        )
    }()

    lazy var dropManager: NoteEditorDropDelegate = {
        return NoteEditorDropDelegate(
            locationProvider: { session in session.location(in: self.view)},
            onDrop: { location, image in
                let aspect = image.size.height / image.size.width
                let reference: CGFloat

                if image.size.width > image.size.height {
                    reference = self.view.frame.width / 4
                } else {
                    reference = self.view.frame.height / 4
                }

                let width = image.size.width > image.size.height ? reference : reference / aspect
                let height = image.size.height >= image.size.width ? reference : reference * aspect

                let actualFrame = CGRect(x: location.x - width / 2,
                                         y: location.y - height / 2,
                                         width: width,
                                         height: height)

                let id: NoteImageID = ID(UUID())
                let vm = self.historian.createImage(id: id, frame: actualFrame, with: image)
                let preview = self.sublevelPreview(frame: actualFrame, preview: image)
                preview.viewModel = vm
                self.view.addSubview(preview)
        })
    }()

    private struct EdgePanGestureState {
        let currentlyDraggedPreview: NoteLevelPreview
    }

    private func edgeGestureRecognizer(edge: UIRectEdge) -> ZNScreenEdgePanGesture<EdgePanGestureState> {
        let edgeGestureRecognizer = ZNScreenEdgePanGesture<EdgePanGestureState>(
            begin: { rec in
                let frame = self.defaultPreviewFrame(from: rec.location(in: self.canvasView))

                let defaultPreviewImage = UIImage.from(size: self.view.frame.size).withBackground(color: UIColor.white)

                let newLevelPreview = self.sublevelPreview(frame: frame,
                                                           preview: defaultPreviewImage)
                self.view.addSubview(newLevelPreview)

                return EdgePanGestureState(currentlyDraggedPreview: newLevelPreview)
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

                let id: NoteLevelID = ID(UUID())
                let vm = self.historian.createLevel(id: id,
                                                    frame: state.currentlyDraggedPreview.frame,
                                                    with: state.currentlyDraggedPreview.image!)

                state.currentlyDraggedPreview.viewModel = vm

        })

        edgeGestureRecognizer.edges = edge
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
        navigationController?.delegate = transitionManager

        setup(canvasView)

        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)
        setup(toolPicker)

        if self.drawerView != nil {
            self.drawerView!.removeFromSuperview()
        }

        let title: Binding<String> = .init(get: { self.viewModel.title },
                                           set: { self.viewModel.title = $0 })

        self.drawerView = DrawerView(title: title, onCameraButtonTapped: { /* NOP */})

        self.view.addSubview(drawerView!)
        self.view.bringSubviewToFront(drawerView!)
        drawerView!.addGestureRecognizer(drawerViewPanGesture)

        drawerView!.snp.makeConstraints { make in
            make.leading.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.width.equalTo(self.view.snp.width)
            make.height.equalTo(self.view.frame.height / 3)
            self.drawerViewTopOffset = make.top.equalTo(self.view.snp.bottom).offset(-50).constraint
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.historian = Historian(undoManager: self.undoManager,
                                   viewModel: self.viewModel)

        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        let interaction = UIDropInteraction(delegate: dropManager)
        self.view.addInteraction(interaction)

        let edges: [UIRectEdge] = [.left, .right]

        edges.forEach { self.view.addGestureRecognizer(edgeGestureRecognizer(edge: $0)) }

        self.viewModel.load { child in
            let sublevel = self.sublevelPreview(frame: child.frame, preview: child.preview)
            sublevel.viewModel = child

            child.$frame
                .sink { sublevel.frame = $0 }
                .store(in: &cancellables)

            child.$preview
                .sink { sublevel.image = $0 }
                .store(in: &cancellables)

            self.canvasView.addSubview(sublevel)
        }

        self.view.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomUp($0) })

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
        self.updateDrawingMeta()
    }

    override func viewDidLayoutSubviews() {
        updateContentSizeForDrawing()
        canvasView.contentOffset = CGPoint(x: 0, y: -canvasView.adjustedContentInset.top)
    }

    @objc func onPinch(_ rec: UIPinchGestureRecognizer) { }

    @objc private func updateDrawingMeta() {
        let screen = capture(
            self.view,
            prepare: { drawerView?.alpha = 0.0 },
            done: { drawerView?.alpha = 1.0 }
        )
        self.previewChangedSubject.send(screen)
        self.viewModel.refresh(image: screen)
    }

    func onPreviewZoomUp(_ rec: ZNPinchGestureRecognizer) {
        if rec.state == .began {
            navigationController?.popViewController(animated: true)
        }

        if rec.state == .changed {
            let percent = clamp(1 - rec.scale, lower: 0, upper: 1)
            transitionManager.step(percent: percent)
        }

        if rec.state == .ended {
            if rec.scale < 0.5 && rec.state != .cancelled {
                transitionManager.finish()
            } else {
                transitionManager.cancel()
            }
        }
    }

    func onPreviewZoomDown(_ rec: ZNPinchGestureRecognizer, _ preview: NoteLevelPreview) {
        guard let vm = preview.viewModel else { return }
        let frameInView = CGRect(x: preview.frame.minX,
                                 y: preview.frame.minY - self.canvasView.contentOffset.y,
                                 width: preview.frame.width,
                                 height: preview.frame.height)

        let ratio = view.bounds.width / preview.frame.width

        if rec.state == .began {
            self.transitionManager = transitionManager.down(animator: ZoomDownTransitionAnimator(destinationRect: frameInView))

            guard let destinationVC = vm.commander.detailViewController(from: storyboard) else {
                return
            }

            switch destinationVC {
            case .image(let imageVC, id: let id):
                imageVC.viewModel = viewModel.imageDetailViewModel(for: id)
                imageVC
                    .previewChanged
                    .sink { image in
                        vm.preview = image
                        self.viewModel.update(id: id, preview: image)

                }
                    .store(in: &cancellables)

                imageVC
                    .drawingChanged
                    .sink { self.viewModel.update(id: id, annotation: $0) }
                    .store(in: &cancellables)

                imageVC.transitionManager =
                    NoteTransitionDelegate()
                        .up(animator: ZoomUpTransitionAnimator(with: vm.frame))

                navigationController?.pushViewController(imageVC, animated: true)

            case .sublevel(let sublevelVC, id: let id):
                sublevelVC.transitionManager =
                    NoteTransitionDelegate()
                        .up(animator: ZoomUpTransitionAnimator(with: vm.frame))
                sublevelVC.viewModel = self.viewModel.childViewModel(for: id)

                sublevelVC
                    .previewChangedSubject
                    .sink { vm.preview = $0 }
                    .store(in: &cancellables)

                navigationController?.pushViewController(sublevelVC, animated: true)
            }
        }

        if rec.state == .changed {
            let scale = clamp(rec.scale, lower: 1, upper: ratio)
            let percent = (scale - 1) / (ratio - 1)
            transitionManager.step(percent: percent)
        }

        if rec.state == .ended {
            guard rec.scale > 2 || rec.state == .cancelled else {
                UIView.animate(withDuration: 0.1) {
                    self.view.transform = .identity
                }
                transitionManager.cancel()
                return
            }
            transitionManager.finish()
            self.view.transform = .identity
        }
    }

    private func showImagePicker() {
        self.drawerViewTopOffset.update(offset: 0)
        self.drawerView!.layoutIfNeeded()

        self.imagePicker =
            UIHostingController(rootView: ImagePickerDrawer(onDismiss: self.hideImagePicker))

        self.view.addSubview(imagePicker!.view)

        imagePicker!.view.snp.makeConstraints { make in
            make.leading.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.width.equalTo(self.view.snp.width)
            make.height.equalTo(self.view.frame.height / 3)
            make.bottom.equalTo(self.view.snp.bottom)
        }
    }

    private func hideImagePicker() {
        guard let view = self.imagePicker?.view else { return }
        view.removeFromSuperview()

        self.view.addSubview(drawerView!)
        self.view.bringSubviewToFront(drawerView!)

        drawerView!.snp.makeConstraints { make in
            make.leading.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.width.equalTo(self.view.snp.width)
            make.height.equalTo(self.view.frame.height / 3)
            self.drawerViewTopOffset = make.top.equalTo(self.view.snp.bottom).offset(-50).constraint
        }

    }
}

extension NoteViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        self.viewModel.update(drawing: canvasView.drawing)
        updateContentSizeForDrawing()
    }

    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }

    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
}

extension NoteViewController {
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

        self.view.bringSubviewToFront(preview)
        return PanGestureState(originalFrame: preview.frame, dragging: preview, origin: origin)
    }

    private func panGestureStep(_ rec: UIPanGestureRecognizer, state: PanGestureState) -> PanGestureState {
        let tran = rec.translation(in: self.view)
        let frame = CGRect(x: max(0, state.dragging.frame.minX + tran.x),
                           y: max(0, state.dragging.frame.minY + tran.y),
                           width: state.dragging.frame.width,
                           height: state.dragging.frame.height)

        state.dragging.frame = frame

        rec.setTranslation(CGPoint.zero, in: self.view)
        return state
    }

    private func panGestureEnded(_ rec: UIPanGestureRecognizer, state: PanGestureState) {
        // MARK: begin snippet
        /// https://www.raywenderlich.com/1860-uikit-dynamics-and-swift-tutorial-tossing-views

        guard let vm = state.dragging.viewModel else { return }

        let velocity = rec.velocity(in: self.canvasView)
        let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))

        let catapult = Catapult(threshold: 4000, in: self.view) {
            self.historian.removeChild(vm, undo: { _ in fatalError("Not implemented") })
        }

        if catapult.tryFling(velocity, magnitude, state.dragging) { return }

        if self.drawerView!.frame.contains(state.dragging.frame) {
            let locInDrawer = rec.location(in: self.drawerView)
            let locInPreview = rec.location(in: state.dragging)
            let frameInDrawer = CGRect(x: locInDrawer.x - locInPreview.x,
                                       y: locInDrawer.y - locInPreview.y,
                                       width: state.dragging.frame.width,
                                       height: state.dragging.frame.height)

            let originalFrame = state.originalFrame
            if state.origin == .canvas {
                self.historian.moveToDrawer(sublevel: vm,
                                            from: originalFrame,
                                            to: frameInDrawer)
            } else {
                self.historian.moveChild(sublevel: vm,
                                         from: originalFrame,
                                         to: frameInDrawer)
            }
        } else {
            let canvasViewOffset = self.canvasView.contentOffset.y
            let newFrame = CGRect(x: state.dragging.frame.minX,
                                  y: state.dragging.frame.minY + canvasViewOffset - self.statusBarHeight,
                                  width: state.dragging.frame.width,
                                  height: state.dragging.frame.height)

            let originalFrame = state.originalFrame

            if state.origin == .drawer {
                self.historian.moveFromDrawer(sublevel: vm, from: originalFrame, to: newFrame)
            } else {
                self.historian.moveChild(sublevel: vm, from: originalFrame, to: newFrame)
            }
        }
    }

    private func panGesture(for preview: NoteLevelPreview) -> ZNPanGestureRecognizer<PanGestureState> {
        return ZNPanGestureRecognizer<PanGestureState>(
            begin: { rec in return self.panGestureBegin(rec, preview) },
            step: self.panGestureStep(_:state:),
            end: { rec, state in self.panGestureEnded(rec, state: state) }
        )
    }

    private struct CloneGestureState {
        let originalFrame: CGRect
        let dragging: NoteLevelPreview
    }

    private func cloneGesture(for preview: NoteLevelPreview) -> ZNPanGestureRecognizer<CloneGestureState> {
        ZNPanGestureRecognizer<CloneGestureState>(
            begin: { rec in
                let newPreview = self.sublevelPreview(frame: preview.frame, preview: preview.image!)
                self.canvasView.addSubview(newPreview)
                return CloneGestureState(originalFrame: preview.frame,
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
                let vm = self.historian.createLevel(id: ID(UUID()),
                                                    frame: state.dragging.frame,
                                                    with: state.dragging.image!)

                state.dragging.viewModel = vm

        })
    }

    func sublevelPreview(frame: CGRect, preview: UIImage) -> NoteLevelPreview {
        let preview = NoteLevelPreview(
            frame: frame,
            preview: preview,
            resizeEnded: { vm, oframe, frame in
                guard let vm = vm else { return }
                self.historian.resizePreview(sublevel: vm, from: oframe, to: frame)
        })

        preview.copyIndicator.addGestureRecognizer(cloneGesture(for: preview))

        preview.addGestureRecognizer(self.panGesture(for: preview))

        preview.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomUp($0) })

        preview.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomDown($0, preview) })

        preview.addGestureRecognizer(ZNTapGestureRecognizer { rec in
            let location = rec.location(in: preview)
            preview.setEdited(in: preview.bounds.half(of: location))
        }.taps(2))

        return preview
    }
}

extension NoteViewController: PKToolPickerObserver { }
