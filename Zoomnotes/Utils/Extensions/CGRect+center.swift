//
//  CGRect+center.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}
