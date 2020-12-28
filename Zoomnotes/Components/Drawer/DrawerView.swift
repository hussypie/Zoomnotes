//
//  DrawerView.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine
import SwiftUI
import SnapKit

class DrawerView: UIView {
    var title: ObservedValue<String>!
    var contents: [UUID: NoteLevelPreview] = [:]
    private var topOffset: Constraint!
    private var cancellables: Set<AnyCancellable> = []

    private lazy var titleTextField: UITextField = {
        let textField = UITextField()

        textField.delegate = self

        textField.addTarget(self, action: #selector(onTextField(_:)), for: .editingChanged)

        textField.placeholder = "Note Title"
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.backgroundColor = UIColor.systemGray5
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.layer.cornerRadius = 5

        /// https://stackoverflow.com/a/51403213
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textField.frame.height))
        textField.leftViewMode = .always

        title.publisher
            .sink(receiveValue: { textField.text = $0 })
            .store(in: &cancellables)

        return textField
    }()

    private lazy var drawerViewPanGesture: ZNPanGestureRecognizer<Void> = {
        return ZNPanGestureRecognizer(
            begin: { _ in },
            step: { [unowned self] rec, _ in
                let touchHeight = rec.location(in: self.superView).y
                let offset = clamp(self.superView.frame.height - touchHeight,
                                   lower: 50,
                                   upper: self.superView.frame.height / 3)
                self.topOffset.update(offset: -offset)
            },
            end: { _, _ in }
        )
    }()

    private var superView: UIView {
        guard let superview = superview else {
            fatalError("Drawer has to be added as a child view")
        }
        return superview
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setup(with title: ObservedValue<String>) {
        self.title = title
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

        self.snp.makeConstraints { [unowned self] make in
            make.leading.equalTo(superView)
            make.trailing.equalTo(superView)
            make.width.equalTo(superView.snp.width)
            make.height.equalTo(superView.frame.height / 3)
            self.topOffset = make.top.equalTo(superView.snp.bottom).offset(-50).constraint
        }

        self.addGestureRecognizer(drawerViewPanGesture)
        self.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            self.endEditing(true)
        })

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
        self.title.update(sender.text ?? "Untitled")
    }

    @objc func keyboardWillChangeFrame(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        UIView.animate(withDuration: 0.1) {
            let offset: CGFloat
            if notification.name == UIResponder.keyboardWillHideNotification {
                offset = -50
            } else {
                let keyboardScreenEndFrame = keyboardValue.cgRectValue
                offset = -(keyboardScreenEndFrame.height + 50)
            }
            self.topOffset.update(offset: offset)
        }
    }
}

extension DrawerView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
}
