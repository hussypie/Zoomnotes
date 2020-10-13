//
//  NoteImageDescription.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 30..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

struct NoteImageDescription {
    let id: NoteImageID
    let preview: UIImage
    let drawing: PKDrawing
    let image: UIImage
    let frame: CGRect
}

extension NoteImageDescription {
    static func from(_ store: ImageStore) -> NoteImageDescription {
        guard let drawing = try? PKDrawing(data: store.drawingAnnotation!) else {
            fatalError("Cannot load drawing from data")
        }
        let rect = CGRect(x: CGFloat(store.frame!.x),
                          y: CGFloat(store.frame!.y),
                          width: CGFloat(store.frame!.width),
                          height: CGFloat(store.frame!.height))

        return NoteImageDescription(id: ID(store.id!),
                                    preview: UIImage(data: store.preview!)!,
                                    drawing: drawing,
                                    image: UIImage(data: store.image!)!,
                                    frame: rect)
    }
}
