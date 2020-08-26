//
//  ZoomTransitionAnimator.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class ZoomTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let note: NoteModel.NoteLevel
    private let duration: TimeInterval = 5
    
    init(with note: NoteModel.NoteLevel) {
        self.note = note
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to) else { return }
        guard let fromView = transitionContext.view(forKey: .from) else { return }

        let container = transitionContext.containerView
        
        toView.transform = CGAffineTransform(scaleX: 2, y: 2)
        
        UIView.animate(withDuration: self.duration, animations: {
            toView.transform = CGAffineTransform(scaleX: 1, y: 1)
        }, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
        })
    }
}
