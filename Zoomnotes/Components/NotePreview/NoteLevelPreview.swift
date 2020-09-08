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
    typealias OnCopyStartedCallback = () -> Void

    private var isEdited: Bool

    private var onResizeEnded: OnResizeEndedCallback
    private var onCopyStarted: OnCopyStartedCallback

    private func indicator(systemName: String, yOffset: CGFloat) -> UIImageView {
        let imageView = UIImageView(image: UIImage(systemName: systemName))
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 15
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.layer.borderWidth = 1
        imageView.backgroundColor = UIColor.white
        return imageView
    }

    lazy var copyIndicator = indicator(systemName: "doc.on.doc", yOffset: 0)
    lazy var resizeIndicator = indicator(systemName: "arrow.up.left.and.arrow.down.right", yOffset: self.frame.height)

    struct ResizeGestureState {
        let aspect: CGFloat
    }

    lazy var resizeGesture: ZNPanGestureRecognizer = {
        return ZNPanGestureRecognizer<ResizeGestureState>(
            begin: { _ in
                return ResizeGestureState(aspect: self.frame.width / self.frame.height)
        },
            step: { rec, state in
                let translation = rec.translation(in: self.resizeIndicator)
                let newFrame = CGRect(x: self.frame.minX,
                                      y: self.frame.minY,
                                      width: self.frame.width + translation.x,
                                      height: self.frame.height + translation.x / state.aspect)
                self.setFrame(to: newFrame)
                rec.setTranslation(CGPoint.zero, in: self.resizeIndicator)
                return state
        }, end: { _, _ in
            self.onResizeEnded(self.frame)
        })
    }()

    lazy var copyGesture: ZNTapGestureRecognizer = {
        return ZNTapGestureRecognizer { _ in
            self.onCopyStarted()
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
         preview: UIImage,
         resizeEnded: @escaping OnResizeEndedCallback,
         copyStarted: @escaping OnCopyStartedCallback
    ) {
        self.isEdited = false
        self.onResizeEnded = resizeEnded
        self.onCopyStarted = copyStarted

        super.init(frame: frame)

        self.image = preview

        self.backgroundColor = UIColor.white
        self.isUserInteractionEnabled = true

        self.addSubview(darklayer)

        self.resizeIndicator.addGestureRecognizer(resizeGesture)
        self.copyIndicator.addGestureRecognizer(copyGesture)

        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        self.layer.shadowOpacity = 0.1
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    private func indicatorFrame(offset: CGPoint) -> CGRect {
        return CGRect(x: offset.x - 15,
                      y: offset.y - 15,
                      width: 30,
                      height: 30)
    }

    func setEdited(in half: Half) {
        if self.isEdited {
            self.removeEditingChrome()
            return
        }
        self.showEditingChrome(in: half)
    }

    func setFrame(to frame: CGRect) {
        self.frame = frame
        self.darklayer.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
    }

    private func removeEditingChrome() {
        self.isEdited = false
        copyIndicator.removeFromSuperview()
        resizeIndicator.removeFromSuperview()
    }

    private func showEditingChrome(in half: Half) {
        self.isEdited = true

        let xOffset: CGFloat
        switch half.opposite {
        case .left:
            xOffset = 0
        case .right:
            xOffset = self.frame.width
        }

        self.copyIndicator.frame = indicatorFrame(offset: CGPoint(x: xOffset, y: 0))
        self.resizeIndicator.frame = indicatorFrame(offset: CGPoint(x: xOffset, y: self.frame.height))

        self.addSubview(copyIndicator)
        self.addSubview(resizeIndicator)
    }

    required init?(coder: NSCoder) {
        fatalError("shit sux")
    }
}
