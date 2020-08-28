//
//  DrawerView.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

protocol DrawerViewDelegate {
    func noteNameChanged(to: String)
}

class DrawerView : UIView {
    
    enum State {
        case hidden
        case partiallyOpen
        case fullyOpen
    }
    
    var delegate: DrawerViewDelegate?
    
    private let offset: CGFloat = 50
    
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
    
    private func titleTextField(title: String) -> UITextField {
        let textField = UITextField(frame: CGRect(x: 10, y: 10, width: 200, height: 30))
        textField.addTarget(self, action: #selector(onTextField(_:)), for: .valueChanged)
        textField.placeholder = "Note Title"
        textField.text = title
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.borderColor = UIColor.systemGray6.cgColor
        textField.borderStyle = .roundedRect
        
        return textField
    }
    
    init(in view: UIView, with title: String) {
        let baseFrame = CGRect(x: 0,
                               y: view.frame.height - offset,
                               width: view.frame.width,
                               height: view.frame.height / 2)
        
        super.init(frame: baseFrame)
        
        self.frame = baseFrame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.layer.cornerRadius = 30
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .prominent))
        blurView.frame = self.bounds
        self.addSubview(blurView)
        
        self.addSubview(titleTextField(title: title))
        
        self.addGestureRecognizer(panGesture(with: view))
        self.addGestureRecognizer(swipeUpGesture(with: view))
        self.addGestureRecognizer(swipeDownGesture(with: view))
        
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(keyboardWillChangeFrame(notification:)),
                       name: UIResponder.keyboardWillChangeFrameNotification,
                       object: nil)
        
    }
    
    @objc func onTextField(_ sender: UITextField) {
        self.delegate?.noteNameChanged(to: sender.text ?? "")
    }
    
    @objc func keyboardWillChangeFrame(notification: Notification) {
//        UIView.animate(withDuration: 0.1) {
//            guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
//
//            self.frame = CGRect(x: 0,
//                                y: <#T##CGFloat#>,
//                                width: self.frame.width,
//                                height: self.frame.height)
//        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
