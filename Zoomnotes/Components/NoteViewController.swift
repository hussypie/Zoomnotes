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
    var note: NoteModel.NoteLevel!
    var hasModifiedDrawing = false
    
    // TODO: tool here
    var circle: NoteLevelPreview? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        canvasView.delegate = self
        canvasView.drawing = note.data.drawing
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
        
        for sublevel in note.children.values {
            self.view.addSubview(newSublevel(for: sublevel))
        }
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if hasModifiedDrawing {
            note.data.drawing = canvasView.drawing
            let screen = captureCurrentScreen()
            note.previewImage = NoteImage(wrapping: screen)
            dataModelController.updatePreview()
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    @objc func screenEdgeSwiped(_ rec: UIScreenEdgePanGestureRecognizer) {
        if rec.state == .changed {
            let loc = rec.location(in: canvasView)
            let width = self.view.frame.width / 4
            let height = self.view.frame.height / 4
            let frame = CGRect(x: loc.x - width / 2,
                               y: loc.y - height / 2,
                               width: width,
                               height: height)
            
            if circle == nil {
                let defaultPreviewImage = UIImage.from(frame: view.frame).withBackground(color: UIColor.white)
                let newLevel = NoteModel.NoteLevel.default(preview: defaultPreviewImage, frame: frame)
                let noteLevelPreview = newSublevel(for: newLevel)
                self.note.children[newLevel.id] = newLevel
                view.addSubview(noteLevelPreview)
                circle = noteLevelPreview
            }
            
            circle!.frame = frame
        }
        
        if rec.state == .ended {
            circle = nil
        }
    }
    
    @objc func onPinch(_ rec: UIPinchGestureRecognizer) { }
    
    private func newSublevel(for sublevel: NoteModel.NoteLevel) -> NoteLevelPreview {
        NoteLevelPreview(frame: sublevel.frame, onMoved: { rec in
            let loc = rec.location(in: self.view)
            sublevel.frame = CGRect(x: loc.x - sublevel.frame.width / 2,
                                   y: loc.y - sublevel.frame.height / 2,
                                   width: sublevel.frame.width,
                                   height: sublevel.frame.height)
            self.hasModifiedDrawing = true
        }) {
            self.note.children.removeValue(forKey: sublevel.id)
        }
    }
    
    private func captureCurrentScreen() -> UIImage {
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
