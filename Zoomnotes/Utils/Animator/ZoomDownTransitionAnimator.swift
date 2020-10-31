//
//  ZoomDownTransitionAnimator.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 05..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class ZoomDownTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let transformStart: CGAffineTransform
    let transformEnd: CGAffineTransform

    private let duration: TimeInterval = 0.2

    init(transformStart: CGAffineTransform, transformEnd: CGAffineTransform) {
        self.transformStart = transformStart
        self.transformEnd = transformEnd
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) else {
            return
        }

        guard let fromVC = transitionContext.viewController(forKey: .from) else {
            return
        }

        let container = transitionContext.containerView

        container.addSubview(fromVC.view)
        fromVC.view.layoutIfNeeded()
        container.transform = self.transformStart

        UIView.animate(withDuration: self.duration, animations: {
            container.transform = self.transformEnd
        }, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            if success {
                container.transform = .identity
                container.addSubview(toVC.view)
                toVC.view.layoutIfNeeded()
            }
            transitionContext.completeTransition(success)
        })
    }
}
