//
//  DrawerView.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class DrawerView : UIVisualEffectView {
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
    
    init(in view: UIView) {
        let baseFrame = CGRect(x: 0,
                               y: view.frame.height - offset,
                               width: view.frame.width,
                               height: view.frame.height / 2)
        
        super.init(effect: UIBlurEffect(style: .prominent))
        
        self.frame = baseFrame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.layer.cornerRadius = 30
        
        self.addGestureRecognizer(panGesture(with: view))
        self.addGestureRecognizer(swipeUpGesture(with: view))
        self.addGestureRecognizer(swipeDownGesture(with: view))
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
