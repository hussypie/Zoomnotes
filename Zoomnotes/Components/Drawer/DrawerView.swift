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
import SnapKit

class DrawerView: UIView {
    var contents: [UUID: NoteLevelPreview] = [:]
    private var topOffset: Constraint!

    private lazy var titleTextField: UITextField = {
        let textField = UITextField()

        textField.delegate = self

        textField.addTarget(self, action: #selector(onTextField(_:)), for: .valueChanged)

        textField.placeholder = "Note Title"
        textField.text = "TODO title"
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

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setup(with title: Binding<String>) {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.addSubview(blurView)

        blurView.snp.makeConstraints { make in
            make.width.equalTo(self.snp.width)
            make.height.equalTo(self.snp.height)
            make.center.equalTo(self)
        }

        _ = self.add(titleTextField) { [unowned self] make in
            make.top.equalTo(self).offset(10)
            make.left.equalTo(self).offset(20)
            make.width.equalTo(200)
            make.height.equalTo(30)
        }

        guard let superview = self.superview else {
            fatalError("Drawer has to be added as a child view")
        }

        self.snp.makeConstraints { [unowned self] make in
            make.leading.equalTo(superview)
            make.trailing.equalTo(superview)
            make.width.equalTo(superview.snp.width)
            make.height.equalTo(superview.frame.height / 3)
            self.topOffset = make.top.equalTo(superview.snp.bottom).offset(-50).constraint
        }

        self.addGestureRecognizer(drawerViewPanGesture)

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

    private lazy var drawerViewPanGesture: ZNPanGestureRecognizer<Void> = {
        return ZNPanGestureRecognizer(
            begin: { _ in },
            step: { [unowned self] rec, _ in
                guard let superview = self.superview else {
                    fatalError("Drawer has to be added as a child view")
                }
                let touchHeight = rec.location(in: superview).y
                let offset = clamp(superview.frame.height - touchHeight,
                                   lower: 50,
                                   upper: superview.frame.height / 3)
                self.topOffset.update(offset: -offset)
            },
            end: { _, _ in }
        )
    }()

    @objc func onTextField(_ sender: UITextField) {
        // TODO
    }

    @objc func keyboardWillChangeFrame(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        guard let view = self.superview else { return }

        UIView.animate(withDuration: 0.1) {
            if notification.name == UIResponder.keyboardWillHideNotification {
                self.frame = CGRect(x: 0,
                                    y: view.frame.height - 50,
                                    width: view.frame.width,
                                    height: view.frame.height / 2)
            } else {
                let keyboardScreenEndFrame = keyboardValue.cgRectValue
                let kbHeight = view.frame.height - keyboardScreenEndFrame.height
                self.frame = CGRect(x: 0,
                                    y: kbHeight - 50,
                                    width: view.frame.width,
                                    height: view.frame.height / 2)
            }
        }
    }
}

extension DrawerView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
}
