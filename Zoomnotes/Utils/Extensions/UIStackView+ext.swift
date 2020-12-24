//
//  UIStackView+ext.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension UIStackView {
    private static func horizontalI(_ views: [UIView]) -> UIStackView {
        let stack = UIStackView()

        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 16.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)

        for view in views {
            stack.addArrangedSubview(view)
            view.sizeToFit()
        }

        return stack
    }

    static func horizontal(_ views: UIView...) -> UIStackView {
        return horizontalI(views)
    }

    static func horizontal(_ views: [UIView]) -> UIStackView {
        return horizontalI(views)
    }

    private static func verticalI(_ views: [UIView]) -> UIStackView {
        let stack = UIStackView()

        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)

        for view in views {
            stack.addArrangedSubview(view)
            view.sizeToFit()
        }

        return stack
    }

    static func vertical(_ views: [UIView]) -> UIStackView {
        return verticalI(views)
    }

    static func vertical(_ views: UIView...) -> UIStackView {
        return verticalI(views)
    }

    func align(_ alignment: UIStackView.Alignment) -> Self {
        self.alignment = alignment
        return self
    }

}
