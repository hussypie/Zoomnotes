//
//  ImageDetailViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 05..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit
import Combine

class ImageDetailViewController: UIViewController {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var canva: PKCanvasView!

    var viewModel: ImageDetailViewModel!
    var transitionManager: NoteTransitionDelegate!
    fileprivate(set) var previewChanged = PassthroughSubject<UIImage, Never>()
    fileprivate(set) var drawingChanged = PassthroughSubject<PKDrawing, Never>()

    var toolPicker: PKToolPicker!

    override var prefersStatusBarHidden: Bool { return true }

    lazy var zoomDownGesture: ZNPinchGestureRecognizer = {
        return ZNPinchGestureRecognizer { [unowned self] rec in
            if rec.state == .began {
                self.navigationController?.popViewController(animated: true)
            }

            if rec.state == .changed {
                let percent = clamp(1 - rec.scale, lower: 0, upper: 1)
                self.transitionManager.step(percent: percent)
            }

            if rec.state == .ended {
                if rec.scale < 0.5 && rec.state != .cancelled {
                    self.transitionManager.finish()
                } else {
                    self.transitionManager.cancel()
                }
            }
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        canva.delegate = self
        canva.becomeFirstResponder()

        canva.isOpaque = false
        canva.backgroundColor = UIColor(white: 0, alpha: 0)

        self.canva.drawing = viewModel.drawing
        self.image.image = viewModel.image

        self.view.addGestureRecognizer(zoomDownGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)

        toolPicker.setVisible(true, forFirstResponder: canva)
        toolPicker.addObserver(canva)
        toolPicker.addObserver(self)

        navigationController?.delegate = transitionManager
    }
}

extension ImageDetailViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        self.drawingChanged.send(canvasView.drawing)
        let screen = self.capture(self.view, prepare: {}, done: {})
        self.previewChanged.send(screen)
    }
}

extension ImageDetailViewController: PKToolPickerObserver {

}