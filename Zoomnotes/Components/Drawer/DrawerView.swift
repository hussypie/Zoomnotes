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

protocol DrawerViewDelegate {
    func noteNameChanged(to: String)
}

class DrawerView : UIView {
    
    enum State {
        case hidden
        case partiallyOpen
        case fullyOpen
    }
    
    private let offset: CGFloat = 50
    
    private let title: Binding<String>
    
    private func panGesture(with view: UIView) -> ZNPanGestureRecognizer {
        let baseFrame = CGRect(x: 0,
                               y: view.frame.height - offset,
                               width: view.frame.width,
                               height: view.frame.height / 2)
        
        return ZNPanGestureRecognizer { rec in
            let pos = rec.location(in: view)
            
            let min = view.frame.height - self.offset
            let max = view.frame.height - view.frame.height / 2 + self.offset
            
            guard pos.y > max else { return }
            
            guard pos.y < min else {
                UIView.animate(withDuration: 0.1) {
                    self.frame = baseFrame
                }
                return
            }
            
            let loc = rec.translation(in: view)
            
            let newY = clamp(self.frame.minY + loc.y, lower: max, upper: min)
            
            self.frame = CGRect(x: 0,
                                y: newY,
                                width: self.frame.width,
                                height: self.frame.height)
            
            rec.setTranslation(CGPoint.zero, in: view)
        }
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
    
    private func titleTextField() -> UITextField {
        let textField = UITextField(frame: CGRect(x: 10, y: 10, width: 200, height: 30))
        
        textField.delegate = self

        textField.addTarget(self, action: #selector(onTextField(_:)), for: .valueChanged)

        textField.placeholder = "Note Title"
        textField.text = title.wrappedValue
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.borderColor = UIColor.systemGray6.cgColor
        textField.borderStyle = .roundedRect
        
        return textField
    }
    
    init(in view: UIView, title: Binding<String>) {
        let baseFrame = CGRect(x: 0,
                               y: view.frame.height - offset,
                               width: view.frame.width,
                               height: view.frame.height / 2)

        self.title = title

        super.init(frame: baseFrame)
        
        self.frame = baseFrame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.layer.cornerRadius = 30
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .prominent))
        blurView.frame = self.bounds
        self.addSubview(blurView)
        
        self.addSubview(titleTextField())
        
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

extension DrawerView : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return true
    }
}
