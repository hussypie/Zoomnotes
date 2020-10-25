//
//  NoteEditorCommandable.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 20..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine
import PencilKit

protocol NoteEditorProtocol {
    func create(id: NoteChildStore, frame: CGRect, preview: UIImage) -> AnyPublisher<NoteChildVM, Error>
    func update(drawing: PKDrawing)
    func refresh(image: UIImage)
    func update(id: NoteImageID, annotation: PKDrawing)
    func update(id: NoteImageID, preview: UIImage)
    func move(child: NoteChildVM, to: CGRect)
    func resize(child: NoteChildVM, to: CGRect)
    func remove(child: NoteChildVM)
    func restore(child: NoteChildVM)
    func moveToDrawer(child: NoteChildVM, frame: CGRect)
    func moveFromDrawer(child: NoteChildVM, frame: CGRect)
}
