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

    fileprivate var toolPicker: PKToolPicker!
    var transitionManager: NoteTransitionDelegate!

    var viewModel: NoteEditorViewModel!

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

                let preview = self.sublevelPreview(frame: actualFrame, preview: image)
                self.view.addSubview(preview)

                self.create(id: .image(ID(UUID())), frame: actualFrame, with: image)
                    .sink(receiveDone: { /* TODO logging */ },
                          receiveError: { _ in /* TODO logging */ },
                          receiveValue: { vm in preview.viewModel = vm })
                    .store(in: &self.cancellables)

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

                self.create(id: .level(ID(UUID())),
                                 frame: state.currentlyDraggedPreview.frame,
                                 with: state.currentlyDraggedPreview.image!)
                    .sink(receiveDone: { /* TODO */ },
                          receiveError: {  _ in /* TODO */ },
                          receiveValue: { vm in state.currentlyDraggedPreview.viewModel = vm })
                    .store(in: &self.cancellables)
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

        self.drawerView = DrawerView(title: title)

        for child in viewModel.drawer.nodes {
            let sublevelView = sublevelPreview(frame: child.frame, preview: child.preview)
            sublevelView.viewModel = child
            self.drawerView?.addSubview(sublevelView)
        }

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

        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        let interaction = UIDropInteraction(delegate: dropManager)
        self.view.addInteraction(interaction)

        let edges: [UIRectEdge] = [.left, .right]

        edges.forEach { self.view.addGestureRecognizer(edgeGestureRecognizer(edge: $0)) }

        for child in self.viewModel.nodes {
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
        super.viewDidLayoutSubviews()

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

            switch vm.store {
            case .level(let id):
                guard let sublevelVC = NoteViewController.from(self.storyboard) else { return }
                sublevelVC.transitionManager =
                        NoteTransitionDelegate()
                            .up(animator: ZoomUpTransitionAnimator(with: vm.frame))

                    sublevelVC
                        .previewChangedSubject
                        .sink { preview in vm.preview = preview }
                        .store(in: &cancellables)

                    self.viewModel.childViewModel(for: id)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { _ in return }, // TODO: log
                              receiveValue: { viewModel in
                                sublevelVC.viewModel = viewModel
                                self.navigationController?.pushViewController(sublevelVC, animated: true)
                        }).store(in: &cancellables)
            case .image(let id):
                guard let imageVC = ImageDetailViewController.from(self.storyboard) else { return }
                imageVC
                    .previewChanged
                    .sink { [weak self] image in
                        vm.preview = image
                        self?.viewModel.update(id: id, preview: image)

                }
                    .store(in: &cancellables)

                imageVC
                    .drawingChanged
                    .sink { self.viewModel.update(id: id, annotation: $0) }
                    .store(in: &cancellables)

                imageVC.transitionManager =
                    NoteTransitionDelegate()
                        .up(animator: ZoomUpTransitionAnimator(with: vm.frame))

                viewModel.imageDetailViewModel(for: id)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in return }, // TODO: signal error
                          receiveValue: { viewModel in
                            imageVC.viewModel = viewModel
                            self.navigationController?.pushViewController(imageVC, animated: true)
                    })
                    .store(in: &self.cancellables)
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
}

extension NoteViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        self.update(from: self.viewModel.drawing, to: canvasView.drawing)
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
            self.removeChild(vm, undo: { _ in fatalError("Not implemented") })
        }

        if catapult.tryFling(velocity, magnitude, state.dragging) {
            state.dragging.removeFromSuperview()
            self.removeChild(vm) { undidvm in
                let preview = self.sublevelPreview(frame: undidvm.frame,
                                                   preview: undidvm.preview)
                preview.viewModel = undidvm
                self.canvasView.addSubview(preview)
            }
            return
        }

        if self.drawerView!.frame.contains(state.dragging.frame) {
            let locInDrawer = rec.location(in: self.drawerView)
            let locInPreview = rec.location(in: state.dragging)
            let frameInDrawer = CGRect(x: locInDrawer.x - locInPreview.x,
                                       y: locInDrawer.y - locInPreview.y,
                                       width: state.dragging.frame.width,
                                       height: state.dragging.frame.height)

            let originalFrame = state.originalFrame
            if state.origin == .canvas {
                self.moveToDrawer(sublevel: vm,
                                            from: originalFrame,
                                            to: frameInDrawer)
                state.dragging.removeFromSuperview()
                self.drawerView?.addSubview(state.dragging)
                state.dragging.frame = frameInDrawer
            } else {
                self.moveChild(sublevel: vm,
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
                self.moveFromDrawer(sublevel: vm, from: originalFrame, to: newFrame)

                state.dragging.removeFromSuperview()
                self.canvasView.addSubview(state.dragging)
                state.dragging.frame = newFrame
            } else {
                self.moveChild(sublevel: vm, from: originalFrame, to: newFrame)
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
                guard let childVM = state.dragging.viewModel else { return }
                let id: NoteChildStore

                switch childVM.store {
                case .level:
                    id = .level(ID(UUID()))
                case .image:
                    id = .image(ID(UUID()))
                }

                self.create(id: id,
                            frame: state.dragging.frame,
                            with: state.dragging.image!)
                    .sink(receiveDone: { /* TODO */ },
                          receiveError: {  _ in /* TODO */ },
                          receiveValue: { vm in state.dragging.viewModel = vm })
                    .store(in: &self.cancellables)
        })
    }

    func sublevelPreview(frame: CGRect, preview: UIImage) -> NoteLevelPreview {
        let preview = NoteLevelPreview(
            frame: frame,
            preview: preview,
            resizeEnded: { vm, oframe, frame in
                guard let vm = vm else { return }
                self.resizePreview(sublevel: vm, from: oframe, to: frame)
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
