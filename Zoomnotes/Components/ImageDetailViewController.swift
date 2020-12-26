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
    var imageView: UIImageView!
    var canva: PKCanvasView!

    var viewModel: ImageDetailViewModel!
    var transitionManager: NoteTransitionDelegate!

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

        self.view.backgroundColor = .systemBackground

        self.imageView = self.view.add(UIImageView(image: viewModel.image)) { [unowned self] make in
            let img = self.viewModel.image
            let aspectRatio = img.size.width / img.size.height
            if img.size.width > img.size.height {
                make.leading.equalTo(self.view.snp.leading)
                make.trailing.equalTo(self.view.snp.trailing)
                make.centerY.equalTo(self.view.snp.centerY)
                make.height.equalTo(self.view.bounds.width / aspectRatio)
            } else {
                make.top.equalTo(self.view.snp.top)
                make.bottom.equalTo(self.view.snp.bottom)
                make.centerX.equalTo(self.view.snp.centerX)
                make.width.equalTo(self.view.bounds.height * aspectRatio)
            }
        }
        self.imageView.contentMode = .scaleAspectFit

        self.canva = self.view.add(PKCanvasView()) { [unowned self] make in
            make.leading.equalTo(self.imageView.snp.leading)
            make.top.equalTo(self.imageView.snp.top)
            make.width.equalTo(self.imageView.snp.width)
            make.height.equalTo(self.imageView.snp.height)
        }

        canva.delegate = self
        canva.becomeFirstResponder()

        canva.isOpaque = false
        canva.backgroundColor = UIColor(white: 0, alpha: 0)

        canva.allowsFingerDrawing = true

        self.canva.drawing = viewModel.drawing
        self.imageView.image = viewModel.image

        self.view.addGestureRecognizer(zoomDownGesture)

        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)

        toolPicker.setVisible(true, forFirstResponder: canva)
        toolPicker.addObserver(canva)
        toolPicker.addObserver(self)

        navigationController?.delegate = transitionManager
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let screen = self.capture(self.view, prepare: {}, done: {})
        self.viewModel.previewChanged.send(screen)
    }
}

extension ImageDetailViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        self.viewModel.setDrawing(drawing: canvasView.drawing)
        let screen = self.capture(self.view, prepare: {}, done: {})
        self.viewModel.previewChanged.send(screen)
    }
}

extension ImageDetailViewController: PKToolPickerObserver {

}
