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
import NotificationBannerSwift

struct DragState {
    let currentlyDraggedLevel: NoteChildVM
    let originalFrame: CGRect
}

// swiftlint:disable type_body_length
class NoteViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var canvasView: PKCanvasView!

    var drawerView: DrawerView? = nil

    fileprivate var toolPicker: PKToolPicker!
    var transitionManager: NoteTransitionDelegate!

    var viewModel: NoteEditorViewModel!
    var logger: LoggerProtocol!

    private var drawerViewTopOffset: Constraint!

    var subLevelViews: [NoteLevelPreview]!

    var interactionController: UIPercentDrivenInteractiveTransition? = nil

    private(set) var previewChangedSubject = PassthroughSubject<UIImage, Never>()

    var cancellables: Set<AnyCancellable> = []

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

    lazy var backButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()

    lazy var plusButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)

        return button
    }()

    lazy var undoButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "arrow.turn.up.left"), for: .normal)
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)

        return button
    }()

    @objc func plusButtonTapped() {
        let id: NoteChildStore = .level(ID(UUID()))
        let frame = CGRect(x: 100,
                           y: 100,
                           width: self.view.frame.width / 4,
                           height: self.view.frame.height / 4)
        let preview = UIImage.from(size: self.view.frame.size).withBackground(color: UIColor.white)
        self.create(id: id, frame: frame, with: preview)
        .sink(receiveDone: { },
              receiveError: { [unowned self] in
                self.logger.warning("Cannot create child level view model, reason: \($0.localizedDescription)")
                FloatingNotificationBanner(title: "Cannot create level", style: .warning).show()
            },
              receiveValue: { [unowned self] vm in
                let contentOffset = self.canvasView.contentOffset
                let startingFrame = CGRect(x: -1000,
                                           y: -1000,
                                           width: frame.width + contentOffset.x,
                                           height: frame.height + contentOffset.y)
                let preview = self.sublevelPreview(frame: startingFrame, preview: preview)
                preview.viewModel = vm
                self.canvasView.addSubview(preview)

                UIView.animate(withDuration: 0.1) {
                    preview.frame = frame
                }

                self.logger.info("Created sublevel via plus button")
        }).store(in: &self.cancellables)
    }

    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func undoButtonTapped() {
        guard let undoManager = self.undoManager else { return }
        if undoManager.canUndo { undoManager.undo() }
    }

    lazy var dropManager: NoteEditorDropDelegate = {
        return NoteEditorDropDelegate(
            locationProvider: { session in session.location(in: self.view)},
            onDrop: { location, image in
                let width = self.view.frame.width / 4
                let height = self.view.frame.height / 4

                let actualFrame = CGRect(x: location.x - width / 2,
                                         y: location.y - height / 2,
                                         width: width,
                                         height: height)

                let preview = self.sublevelPreview(frame: actualFrame, preview: image)
                self.view.addSubview(preview)

                self.logger.info("Created subimage via dropping")

                self.create(id: .image(ID(UUID())), frame: actualFrame, with: image)
                    .sink(receiveDone: { /* TODO logging */ },
                          receiveError: { _ in /* TODO logging */ },
                          receiveValue: { [unowned self] vm in
                            preview.viewModel = vm
                            self.logger.info("Set view model of preview to vm (id: \(vm.id)")

                    })
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

                self.logger.info("Beginning edge pan gesture")
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
                self.logger.info("Ended edge pan gesture")
                let velocity = rec.velocity(in: self.canvasView)
                let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))

                let catapult = Catapult(threshold: 4000, in: self.view) { }

                if catapult.tryFling(velocity, magnitude, state.currentlyDraggedPreview) {
                    self.logger.info("Flung out child preview")
                    return
                }

                self.create(id: .level(ID(UUID())),
                            frame: state.currentlyDraggedPreview.frame,
                            with: state.currentlyDraggedPreview.image!)
                    .sink(receiveDone: { },
                          receiveError: { [unowned self] in
                            self.logger.warning("Cannot create sublevel via edge gesture, reason: \($0.localizedDescription)")
                        },
                          receiveValue: { vm in
                            state.currentlyDraggedPreview.viewModel = vm
                            self.logger.info("Creates sublevel via edge gesture")
                    })
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
        self.logger.info("Setting up canvas view")
        canvasView.delegate = self
        canvasView.drawing = viewModel.drawing
        canvasView.alwaysBounceVertical = true

        #if targetEnvironment(simulator)
        canvasView.allowsFingerDrawing = false
        #else
        canvasView.allowsFingerDrawing = false
        #endif

        canvasView.becomeFirstResponder()
    }

    private func setup(_ toolPicker: PKToolPicker) {
        self.logger.info("Setting up tool picker")
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        toolPicker.addObserver(self)

        updateLayout(for: toolPicker)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.horizontalSizeClass == .compact {
            self.view.addSubview(self.undoButton)
            self.undoButton.snp.makeConstraints { make in
                make.width.equalTo(50)
                make.height.equalTo(50)
                make.trailing.equalTo(self.plusButton.snp.leading)
                make.top.equalTo(10)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationController?.delegate = transitionManager

        setup(canvasView)

        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)
        setup(toolPicker)

        self.logger.info("Setting up drawer view")
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

        self.view.addSubview(self.backButton)
        self.backButton.snp.makeConstraints { make in
            make.leading.equalTo(10)
            make.top.equalTo(10)
            make.width.equalTo(50)
            make.height.equalTo(50)
        }

        self.view.addSubview(self.plusButton)
        self.plusButton.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.top.equalTo(10)
            make.width.equalTo(50)
            make.height.equalTo(50)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        // swiftlint:disable:next force_cast
        let appdelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.logger = appdelegate.logger

        self.logger.info("Setting drop interaction")

        let interaction = UIDropInteraction(delegate: dropManager)
        self.view.addInteraction(interaction)

        self.logger.info("Setting up edge gesture swipe in interaction")
        let edges: [UIRectEdge] = [.left, .right]

        edges.forEach { self.view.addGestureRecognizer(edgeGestureRecognizer(edge: $0)) }

        self.logger.info("Adding children to view")

        self.subLevelViews = []
        for child in self.viewModel.nodes {
            let sublevel = self.sublevelPreview(frame: child.frame, preview: child.preview)
            sublevel.viewModel = child

            child.$frame
                .sink { sublevel.frame = $0 }
                .store(in: &cancellables)

            child.$preview
                .sink {
                    sublevel.image = $0
            }
                .store(in: &cancellables)

            self.canvasView.addSubview(sublevel)
        }

        self.logger.info("Adding zoom up pinch gesture recognizer")
        self.view.addGestureRecognizer(ZNPinchGestureRecognizer { self.onPreviewZoomUp($0) })

        self.logger.info("Adding observers")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateDrawingMeta),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateDrawingMeta),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        self.canvasView.snp.makeConstraints { [unowned self] make in
            make.width.equalTo(self.view.snp.width)
            make.height.equalTo(self.view.snp.height)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.updateDrawingMeta()
    }

    @objc private func updateDrawingMeta() {
        let screen = capture(
            self.view,
            prepare: {
                drawerView?.alpha = 0.0
                self.backButton.alpha = 0.0
                self.plusButton.alpha = 0.0

        },
            done: {
                drawerView?.alpha = 1.0
                self.backButton.alpha = 1.0
                self.plusButton.alpha = 1.0
        })

        self.viewModel
            .refresh(image: screen)
            .sink(
                receiveDone: { },
                receiveError: { [unowned self] error in
                    self.logger.warning("Cannot refresh preview image, reason: \(error.localizedDescription)")
                },
                receiveValue: { [unowned self] in
                    self.previewChangedSubject.send(screen)
            }).store(in: &self.cancellables)
    }

    func onPreviewZoomUp(_ rec: ZNPinchGestureRecognizer) {
        if rec.state == .began {
            self.logger.info("Began zoom up gesture")
            navigationController?.popViewController(animated: true)
        }

        if rec.state == .changed {
            let percent = clamp(1 - rec.scale, lower: 0, upper: 1)
            transitionManager.step(percent: percent)
        }

        if rec.state == .ended {
            if rec.scale < 0.5 && rec.state != .cancelled {
                self.logger.info("Finished zoom up gesture")
                transitionManager.finish()
            } else {
                self.logger.info("Cancelled zoom up gesture")
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
            self.logger.info("Began zoom down gesture")
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
                    .setFailureType(to: Error.self)
                    .flatMap { [unowned self] image in
                        self.viewModel
                            .update(id: id, preview: image)
                            .map { _ in image }
                }.sink(receiveDone: { },
                      receiveError: { [unowned self] error in
                        self.logger.warning("Cannot update preview image of id: \(id), reason: \(error.localizedDescription)")
                    },
                      receiveValue: { [unowned self] image in
                        vm.preview = image
                        self.logger.info("Updated preview image of id: \(id)")
                })
                .store(in: &cancellables)

                imageVC
                    .drawingChanged
                    .setFailureType(to: Error.self)
                    .flatMap { self.viewModel.update(id: id, annotation: $0) }
                    .sink(receiveDone: { },
                          receiveError: { [unowned self] error in
                            self.logger.warning("Cannot update annotation of id: \(id), reason: \(error.localizedDescription)")
                        },
                          receiveValue: { [unowned self] in
                            self.logger.info("Updated annotation of id: \(id)")
                    })
                    .store(in: &cancellables)

                imageVC.transitionManager =
                    NoteTransitionDelegate()
                        .up(animator: ZoomUpTransitionAnimator(with: vm.frame))

                viewModel.imageDetailViewModel(for: id)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in return }, // TODO: signal error
                        receiveValue: { viewModel in
                            imageVC.viewModel = viewModel
                            self.logger.info("Began zoom down gesture")
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
                UIView.animate(
                    withDuration: 0.1,
                    animations: { self.view.transform = .identity },
                    completion: { [unowned self] _ in
                        self.transitionManager.cancel()
                        self.logger.info("Cancelled zoom down gesture")
                        return
                })
                return
            }

            transitionManager.finish()
            self.logger.info("Finished zoom down gesture")
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
            self.logger.info("Began child pan gesture from drawer")
        } else {
            origin = .canvas
            self.logger.info("Began child pan gesture from canvas")
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
            self.removeChild(vm)
        }

        if catapult.tryFling(velocity, magnitude, state.dragging) {
            state.dragging.removeFromSuperview()
            self.removeChild(vm)
            self.logger.info("Pan gestur ended with child flung out")
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
                self.logger.info("Child (id: \(vm.id)) moved to drawer")
            } else {
                self.moveChild(sublevel: vm,
                               from: originalFrame,
                               to: frameInDrawer)
                self.logger.info("Child (id: \(vm.id)) moved")
            }
        } else {
            let canvasViewOffset = self.canvasView.contentOffset
            let newFrame = CGRect(x: state.dragging.frame.minX + canvasViewOffset.x,
                                  y: state.dragging.frame.minY + canvasViewOffset.y - self.statusBarHeight,
                                  width: state.dragging.frame.width,
                                  height: state.dragging.frame.height)

            let originalFrame = state.originalFrame

            state.dragging.removeFromSuperview()

            if state.origin == .drawer {
                self.moveFromDrawer(sublevel: vm, from: originalFrame, to: newFrame)
                state.dragging.frame = newFrame
                self.logger.info("Child (id: \(vm.id)) moved to canvas")
            } else {
                self.moveChild(sublevel: vm, from: originalFrame, to: newFrame)
                self.logger.info("Child (id: \(vm.id)) moved")
            }

            self.canvasView.addSubview(state.dragging)

            updateContentSizeForDrawing()
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

        self.subLevelViews.append(preview)

        return preview
    }
}

extension NoteViewController: PKToolPickerObserver { }
