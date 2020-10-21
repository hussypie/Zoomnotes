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
    let title: Binding<String>

    var contents: [UUID: NoteLevelPreview] = [:]

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

    init(title: Binding<String>) {
        self.title = title
        super.init(frame: CGRect.zero)

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .prominent))
        self.addSubview(blurView)

        blurView.snp.makeConstraints { make in
            make.width.equalTo(self.snp.width)
            make.height.equalTo(self.snp.height)
            make.center.equalTo(self)
        }

        self.addSubview(titleTextField)
        self.bringSubviewToFront(titleTextField)

        titleTextField.snp.makeConstraints { make in
            make.top.equalTo(self).offset(10)
            make.left.equalTo(self).offset(20)
            make.width.equalTo(200)
            make.height.equalTo(30)
        }

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
