//
//  DrawerView.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

struct PanGestureState {
    let baseFrame: CGRect
}

class DrawerView: UIView {
    private let offset: CGFloat = 50

    var title: Binding<String>

    var contents: [UUID: NoteLevelPreview]

    private func panGestureStep(_ rec: UIPanGestureRecognizer,
                                state: PanGestureState,
                                view: UIView) -> PanGestureState {
        let pos = rec.location(in: view)

        let min = view.frame.height - self.offset
        let max = view.frame.height - view.frame.height / 2 + self.offset

        guard pos.y > max else { return state }

        guard pos.y < min else {
            UIView.animate(withDuration: 0.1) {
                self.frame = state.baseFrame
            }
            return state
        }

        let loc = rec.translation(in: view)

        let newY = clamp(self.frame.minY + loc.y, lower: max, upper: min)

        self.frame = CGRect(x: 0,
                            y: newY,
                            width: self.frame.width,
                            height: self.frame.height)

        rec.setTranslation(CGPoint.zero, in: view)

        return state
    }

    private func panGesture(with view: UIView) -> ZNPanGestureRecognizer<PanGestureState> {
        return ZNPanGestureRecognizer(
            begin: { _ in
                return PanGestureState(baseFrame: CGRect(x: 0,
                                                         y: view.frame.height - self.offset,
                                                         width: view.frame.width,
                                                         height: view.frame.height / 2))

        },
            step: { return self.panGestureStep($0, state: $1, view: view) },
            end: { _, _ in })
    }

    private func swipeUpGesture(with view: UIView) -> ZNSwipeGestureRecognizer {
        let targetFrame = CGRect(x: 0,
                                 y: view.frame.height - view.frame.height / 2 + self.offset,
                                 width: view.frame.width,
                                 height: view.frame.height / 2)

        return ZNSwipeGestureRecognizer(direction: .up) { _ in
            UIView.animate(withDuration: 0.1) {
                self.frame = targetFrame
            }
        }
    }

    private func swipeDownGesture(with view: UIView) -> ZNSwipeGestureRecognizer {
        let targetFrame = CGRect(x: 0,
                                 y: view.frame.height - offset,
                                 width: view.frame.width,
                                 height: view.frame.height / 2)

        return ZNSwipeGestureRecognizer(direction: .down) { _ in
            UIView.animate(withDuration: 0.1) {
                self.frame = targetFrame
            }
        }
    }

    lazy var titleTextField: UITextField = {
        let textField = UITextField()

        textField.delegate = self

        textField.addTarget(self, action: #selector(onTextField(_:)), for: .valueChanged)

        textField.placeholder = "Note Title"
        textField.text = title.wrappedValue
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.backgroundColor = UIColor.systemGray5
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.layer.cornerRadius = 5

        /// https://stackoverflow.com/a/51403213
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textField.frame.height))
        textField.leftViewMode = .always

        return textField
    }()

    init(in view: UIView, title: Binding<String>) {
        let baseFrame = CGRect(x: 0,
                               y: view.frame.height - offset,
                               width: view.frame.width,
                               height: view.frame.height / 2)

        self.title = title
        self.contents = [:]

        super.init(frame: baseFrame)

        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.layer.cornerRadius = 30

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .prominent))
        blurView.frame = self.bounds
        self.addSubview(blurView)

        self.addSubview(titleTextField)
        NSLayoutConstraint.activate([
            titleTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor,
                                                    constant: self.safeAreaInsets.left),
            titleTextField.topAnchor.constraint(equalTo: self.topAnchor,
                                                constant: self.safeAreaInsets.top)
        ])

        self.addGestureRecognizer(panGesture(with: view))
        self.addGestureRecognizer(swipeUpGesture(with: view))
        self.addGestureRecognizer(swipeDownGesture(with: view))

        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(keyboardWillChangeFrame(notification:)),
                       name: UIResponder.keyboardWillChangeFrameNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(keyboardWillChangeFrame(notification:)),
                       name: UIResponder.keyboardWillHideNotification,
                       object: nil)
    }

    @objc func onTextField(_ sender: UITextField) {
        self.title.wrappedValue = sender.text ?? "Untitled"
    }

    @objc func keyboardWillChangeFrame(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        guard let view = self.superview else { return }

        UIView.animate(withDuration: 0.1) {
            if notification.name == UIResponder.keyboardWillHideNotification {
                self.frame = CGRect(x: 0,
                                    y: view.frame.height - self.offset,
                                    width: view.frame.width,
                                    height: view.frame.height / 2)
            } else {
                let keyboardScreenEndFrame = keyboardValue.cgRectValue
                let kbHeight = view.frame.height - keyboardScreenEndFrame.height
                self.frame = CGRect(x: 0,
                                    y: kbHeight - self.offset,
                                    width: view.frame.width,
                                    height: view.frame.height / 2)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DrawerView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
}
