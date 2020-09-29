//
//  NoteLevelDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit
import UIKit

struct NoteLevelDescription {
    let preview: UIImage
    let frame: CGRect
    let id: UUID
    let drawing: PKDrawing
    let sublevels: [NoteLevelDescription]
}

extension NoteLevelDescription {
    static func from(store: NoteLevelStore) throws -> NoteLevelDescription? {
        let frame = CGRect(x: CGFloat(store.frame!.x),
                           y: CGFloat(store.frame!.y),
                           width: CGFloat(store.frame!.width),
                           height: CGFloat(store.frame!.height))

        let drawing = try PKDrawing(data: store.drawing!)

        guard let sublevels = store.sublevels as? Set<NoteLevelStore> else { return nil }

        return NoteLevelDescription(preview: UIImage(data: store.preview!)!,
                                    frame: frame,
                                    id: store.id!,
                                    drawing: drawing,
                                    sublevels: sublevels.compactMap { try? NoteLevelDescription.from(store: $0) })
    }
}
