//
//  NoteLevelPreview.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 19..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

class NoteLevelPreview: UIImageView {
    typealias OnResizeEndedCallback = (CGRect) -> Void

    var isEdited: Bool {
        didSet {
            if isEdited {
                showEditingChrome()
            } else {
                removeEditingChrome()
            }
        }
    }

    private var onResizeEnded: OnResizeEndedCallback
    private var onCopyStarted: () -> Void

    private func indicator(systemName: String, yOffset: CGFloat) -> UIImageView {
        let inset: CGFloat = -2
        let imageView = UIImageView(image: UIImage(systemName: systemName)?
            .withAlignmentRectInsets(UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)))
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 15
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.layer.borderWidth = 1
        imageView.backgroundColor = UIColor.white
        imageView.frame = indicatorFrame(yOffset: yOffset)
        return imageView
    }

    lazy var copyIndicator = indicator(systemName: "doc.on.doc", yOffset: 0)
    lazy var resizeIndicator = indicator(systemName: "arrow.up.left.and.arrow.down.right", yOffset: self.frame.height)

    lazy var resizeGesture: ZNPanGestureRecognizer = {
        return ZNPanGestureRecognizer { rec in
            let translation = rec.translation(in: self.superview)
            let aspect = self.frame.width / self.frame.height
            let newFrame = CGRect(x: self.frame.minX,
                                  y: self.frame.minY,
                                  width: self.frame.width + translation.x,
                                  height: self.frame.height + translation.x / aspect)
            self.setFrame(to: newFrame)
            rec.setTranslation(CGPoint.zero, in: self.superview)

            if rec.state == .ended {
                self.onResizeEnded(self.frame)
            }
        }
    }()

    lazy var darklayer: UIView = {
        let darklayer = UIView(frame: CGRect(x: 0,
                                             y: 0,
                                             width: frame.width,
                                             height: frame.height))
        darklayer.backgroundColor = UIColor.darkGray
        darklayer.layer.opacity = 0.02
        return darklayer
    }()

    init(frame: CGRect,
         resizeEnded: @escaping OnResizeEndedCallback,
         copyStarted: @escaping () -> Void
    ) {
        self.isEdited = false
        self.onResizeEnded = resizeEnded
        self.onCopyStarted = copyStarted

        super.init(frame: frame)

        self.backgroundColor = UIColor.white
        self.isUserInteractionEnabled = true

        self.addSubview(darklayer)

        self.resizeIndicator.addGestureRecognizer(resizeGesture)

        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        self.layer.shadowOpacity = 0.1
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    private func indicatorFrame(yOffset: CGFloat) -> CGRect {
        return CGRect(x: self.frame.width - 15,
                      y: yOffset - 15,
                      width: 30,
                      height: 30)
    }

    private func setFrame(to frame: CGRect) {
        self.frame = frame
        self.darklayer.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        self.copyIndicator.frame = indicatorFrame(yOffset: 0)
        self.resizeIndicator.frame = indicatorFrame(yOffset: self.frame.height)
        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
    }

    private func removeEditingChrome() {
        copyIndicator.removeFromSuperview()
        resizeIndicator.removeFromSuperview()
    }

    private func showEditingChrome() {
        self.addSubview(copyIndicator)
        self.addSubview(resizeIndicator)
    }

    required init?(coder: NSCoder) {
        fatalError("shit sux")
    }
}
