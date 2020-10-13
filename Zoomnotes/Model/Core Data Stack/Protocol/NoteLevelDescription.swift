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
    let id: NoteLevelID
    let drawing: PKDrawing
    let sublevels: [NoteLevelDescription]
    let images: [NoteImageDescription]
}

extension NoteLevelDescription {
    static func from(store: NoteLevelStore) throws -> NoteLevelDescription? {
        let frame = CGRect(x: CGFloat(store.frame!.x),
                           y: CGFloat(store.frame!.y),
                           width: CGFloat(store.frame!.width),
                           height: CGFloat(store.frame!.height))

        let drawing = try PKDrawing(data: store.drawing!)

        guard let sublevels = store.sublevels as? Set<NoteLevelStore> else { return nil }
        guard let images = store.images as? Set<ImageStore> else { return nil }

        return NoteLevelDescription(
            preview: UIImage(data: store.preview!)!,
            frame: frame,
            id: ID(store.id!),
            drawing: drawing,
            sublevels: sublevels.compactMap { try? NoteLevelDescription.from(store: $0) },
            images: images.map { NoteImageDescription.from($0) }
        )
    }
}
