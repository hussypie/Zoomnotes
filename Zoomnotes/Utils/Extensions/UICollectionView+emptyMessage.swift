//
//  UICollectionView+emptyMessage.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

/// adapted from https://stackoverflow.com/a/48579470
extension UICollectionView {
    func setEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0,
                                                 y: 0,
                                                 width: self.bounds.size.width,
                                                 height: self.bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = .black
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 32)
        messageLabel.textColor = .systemGray
        messageLabel.sizeToFit()

        self.backgroundView = messageLabel
    }

    func unsetEmptyMessage() {
        self.backgroundView = nil
    }
}
