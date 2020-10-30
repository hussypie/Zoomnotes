//
//  NoteViewController+utils.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 08..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

extension NoteViewController {
    func updateContentSizeForDrawing() {
        let offset = canvasView.contentOffset
        let confortableDrawingHeight =
            `if`(canvasView.drawing.bounds.isNull, then: {
                return canvasView.drawing.bounds.maxY * 1.5 * canvasView.zoomScale
            }, else: {
                return canvasView.bounds.height
            })

        let maxSubviewHeight = self.viewModel.nodes.reduce(0) { res, child in
            return max(res, child.frame.maxY * 1.5)
        }

        canvasView.contentSize = CGSize(width: view.frame.width * canvasView.zoomScale,
                                        height: max(confortableDrawingHeight, maxSubviewHeight))
        canvasView.setContentOffset(offset, animated: false)
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
