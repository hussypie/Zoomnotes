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

class NoteLevelPreview: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.white
        let darklayer = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        darklayer.backgroundColor = UIColor.darkGray
        darklayer.layer.opacity = 0.1
        self.addSubview(darklayer)
        
        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        self.layer.shadowOpacity = 0.1
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self,
                                                          action: #selector(panGesture(_:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        self.addGestureRecognizer(panGestureRecognizer)
        
        let zoomGestureRecognizer = UIPinchGestureRecognizer(target: self,
                                                             action: #selector(pinchGesture(_:)))
        self.addGestureRecognizer(zoomGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc func panGesture(_ rec: UIPanGestureRecognizer) {
        let loc = rec.location(in: self.superview!)
        let velocity = rec.velocity(in: self.superview)
        
        if rec.state == .changed {
            self.frame = CGRect(x: loc.x - self.frame.width / 2,
                                y: loc.y - self.frame.height / 2,
                                width: self.frame.width,
                                height: self.frame.height)
            
        } else if rec.state == .ended {
            // MARK: begin snippet
            /// https://www.raywenderlich.com/1860-uikit-dynamics-and-swift-tutorial-tossing-views
            
            let magnitude: CGFloat = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
            
            let threshold: CGFloat = 5000
            let velocityPadding: CGFloat  = 35
            
            if magnitude > threshold {
                let animator = UIDynamicAnimator(referenceView: self.superview!)
                let pushBehavior = UIPushBehavior(items: [self], mode: .instantaneous)
                pushBehavior.pushDirection = CGVector(dx: velocity.x / 10, dy: velocity.y / 10)
                pushBehavior.magnitude = magnitude / velocityPadding
                
                animator.addBehavior(pushBehavior)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    animator.removeAllBehaviors()
                    self.removeFromSuperview()
                }
            }
            
            // MARK: end snippet
        }
    }
    
    @objc func pinchGesture(_ rec: UIPinchGestureRecognizer) {
        if rec.state == .changed {
            
        }
    }
}
