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
        let drawing = canvasView.drawing

        let contentWidth: CGFloat
        let contentHeight: CGFloat
        if !drawing.bounds.isNull {
            contentHeight = max(canvasView.bounds.height, (drawing.bounds.maxY * 1.5) * canvasView.zoomScale)
            contentWidth = max(canvasView.bounds.width, (drawing.bounds.maxX * 1.5) * canvasView.zoomScale)
        } else {
            contentHeight = canvasView.bounds.height
            contentWidth = canvasView.bounds.width
        }

        let maxChildX = self.viewModel.nodes.reduce(0) { res, child in max(res, child.frame.maxX * 1.5)}
        let maxChildY = self.viewModel.nodes.reduce(0) { res, child in max(res, child.frame.maxY * 1.5)}

        canvasView.contentSize = CGSize(width: max(maxChildX, contentWidth),
                                        height: max(maxChildY, contentHeight))
    }

    func updateLayout(for toolPicker: PKToolPicker) {
        let obscuredFrame = toolPicker.frameObscured(in: view)

        if obscuredFrame.isNull {
            canvasView.contentInset = .zero
            navigationItem.rightBarButtonItems = []
        } else {
            canvasView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.maxY - obscuredFrame.minY, right: 0)
        }

        canvasView.scrollIndicatorInsets = canvasView.contentInset
    }
}
