//
//  ZoomnotesNavigationController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

class ZoomNotesNavigationController : UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    private func updateNavigationBarBackground() {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIColor.secondarySystemBackground.withAlphaComponent(0.95).set()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1)).fill()
        navigationBar.setBackgroundImage(UIGraphicsGetImageFromCurrentImageContext(), for: .default)
        UIGraphicsEndImageContext()
        
    }
}
