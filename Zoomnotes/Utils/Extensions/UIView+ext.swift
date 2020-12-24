//
//  UIView+ext.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

extension UIView {
    func add<T: UIView>(_ view: T, constrain: (SnapKit.ConstraintMaker) -> Void) -> T {
        self.addSubview(view)
        view.snp.makeConstraints(constrain)
        return view
    }

    /// adapted from https://stackoverflow.com/a/30953471
    func blur(style: UIBlurEffect.Style) -> Self {
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(blurEffectView)
        self.sendSubviewToBack(blurEffectView)
        return self
    }
}
