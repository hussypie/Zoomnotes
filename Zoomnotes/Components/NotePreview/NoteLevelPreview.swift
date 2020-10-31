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
import SnapKit

class NoteLevelPreview: UIImageView {
    var viewModel: NoteChildVM?
    typealias OnResizeEndedCallback = (NoteChildVM?, CGRect, CGRect) -> Void

    private var isEdited: Bool

    private var onResizeEnded: OnResizeEndedCallback

    private func indicator(systemName: String, yOffset: CGFloat) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image =
            UIImage(systemName: systemName)!
                .resizableImage(withCapInsets: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        imageView.isUserInteractionEnabled = true
        imageView.layer.cornerRadius = 5
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.layer.borderWidth = 2
        imageView.layer.backgroundColor = UIColor.white.cgColor
        return imageView
    }

    lazy var copyIndicator = indicator(systemName: "doc.on.doc", yOffset: 0)
    lazy var resizeIndicator = indicator(systemName: "arrow.up.left.and.arrow.down.right", yOffset: self.frame.height)

    struct ResizeGestureState {
        let aspect: CGFloat
        let originalFrame: CGRect
    }

    lazy var resizeGesture: ZNPanGestureRecognizer = {
        return ZNPanGestureRecognizer<ResizeGestureState>(
            begin: { _ in
                return ResizeGestureState(aspect: self.frame.width / self.frame.height,
                                          originalFrame: self.frame)
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
        }, end: { _, state in
            self.onResizeEnded(self.viewModel, state.originalFrame, self.frame)
        })
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
         resizeEnded: @escaping OnResizeEndedCallback
    ) {
        self.isEdited = false
        self.onResizeEnded = resizeEnded
        self.viewModel = nil

        super.init(frame: frame)

        self.contentMode = .scaleAspectFit

        self.image = preview

        self.backgroundColor = UIColor.white
        self.isUserInteractionEnabled = true

        self.addSubview(darklayer)

        self.resizeIndicator.addGestureRecognizer(resizeGesture)

        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        self.layer.shadowOpacity = 0.1
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
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

        self.addSubview(copyIndicator)
        self.addSubview(resizeIndicator)

        self.copyIndicator.snp.makeConstraints { make in
            make.width.equalTo(30)
            make.height.equalTo(30)
            make.centerX.equalTo(xOffset)
            make.centerY.equalTo(0)
        }
        self.resizeIndicator.snp.makeConstraints { make in
            make.width.equalTo(30)
            make.height.equalTo(30)
            make.centerX.equalTo(xOffset)
            make.centerY.equalTo(self.frame.height)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("shit sux")
    }
}
