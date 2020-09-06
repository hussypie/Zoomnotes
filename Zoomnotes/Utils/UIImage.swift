//
//  UIImage+withBackgroundColor.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

/// https://stackoverflow.com/a/53500161

extension UIImage {
  func withBackground(color: UIColor, opaque: Bool = true) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)

    guard let ctx = UIGraphicsGetCurrentContext(), let image = cgImage else { return self }
    defer { UIGraphicsEndImageContext() }

    let rect = CGRect(origin: .zero, size: size)
    ctx.setFillColor(color.cgColor)
    ctx.fill(rect)
    ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height))
    ctx.draw(image, in: rect)

    return UIGraphicsGetImageFromCurrentImageContext() ?? self
  }
}

extension UIImage {
    static func from(frame: CGRect) -> UIImage {
        UIGraphicsBeginImageContext(frame.size)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
