//
//  NoteViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit

class NoteViewController : UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    var toolPicker: PKToolPicker!
    
    var dataModelController: DataModelController!
    var note: NoteModel!
    var hasModifiedDrawing = false
    
    // TODO: tool here
    var circle: NoteLevelPreview? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        canvasView.delegate = self
        canvasView.drawing = note.root.data.drawing
        canvasView.alwaysBounceVertical = true
        
        canvasView.isScrollEnabled = false
        canvasView.allowsFingerDrawing = true
        
        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)
        
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        toolPicker.addObserver(self)
        updateLayout(for: toolPicker)
        canvasView.becomeFirstResponder()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        let edgeGestureRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped(_:)))
        edgeGestureRecognizer.edges = .right
        edgeGestureRecognizer.delegate = self
        
        self.view.addGestureRecognizer(edgeGestureRecognizer)
        
        let zoomGestureRecognizer = UIPinchGestureRecognizer(target: self,
                                                       action: #selector(onPinch(_:)))
        self.view.addGestureRecognizer(zoomGestureRecognizer)
    }
    
    @objc func screenEdgeSwiped(_ rec: UIScreenEdgePanGestureRecognizer) {
        if rec.state == .began {
            self.note.addSublevel(level: NoteModel.NoteLevel.default)
        }
        
        if rec.state == .changed {
            let loc = rec.location(in: canvasView)
            let frame = CGRect(x: loc.x - 100, y: loc.y - 100, width: 200, height: 200)
            if circle == nil {
                let circleView = NoteLevelPreview(frame: frame)
                view.addSubview(circleView)
                circle = circleView
            }
            
            circle!.frame = frame
        }
        
        if rec.state == .ended {
            circle = nil
        }
    }
    
    @objc func onPinch(_ rec: UIPinchGestureRecognizer) {
        if rec.state == .changed {
            
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let canvasScale = canvasView.bounds.width / DrawingModel.canvasWidth
        canvasView.minimumZoomScale = canvasScale
        canvasView.maximumZoomScale = canvasScale
        canvasView.zoomScale = canvasScale
        
        canvasView.contentOffset = CGPoint(x: 0, y: -canvasView.adjustedContentInset.top)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if hasModifiedDrawing {
            note.updateDrawing(with: canvasView.drawing)
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    func setNewDrawingUndoable(_ newDrawing: PKDrawing) {
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
