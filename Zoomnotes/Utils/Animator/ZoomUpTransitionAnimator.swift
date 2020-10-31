//
//  ZoomTransitionAnimator.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class ZoomUpTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
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
        guard let toVC = transitionContext.viewController(forKey: .to) else { return }

        let container = transitionContext.containerView
        container.addSubview(toVC.view)
        toVC.view.layoutIfNeeded()

        toVC.view.frame = transitionContext.finalFrame(for: toVC)

        container.transform = transformEnd

        UIView.animate(withDuration: self.duration, animations: {
            container.transform = self.transformStart
        }, completion: { _ in
            let success = !transitionContext.transitionWasCancelled
            transitionContext.completeTransition(success)
        })
    }
}
