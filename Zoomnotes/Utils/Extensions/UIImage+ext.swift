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
    static func from(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in }
    }
}

extension UIImage {
    static func folder() -> UIImage {
        UIImage(named: "folder")!
    }
}

enum SFSymbol: String {
    case plus
    case trash
    case xmark
    case arrowLeft = "arrow.left"
    case arrowTurnUpLeft = "arrow.turn.up.left"
    case chevronDownCircle = "chevron.down.circle"
}

extension UIImage {
    convenience init(sfSymbol: SFSymbol) {
        self.init(systemName: sfSymbol.rawValue)!
    }
}
