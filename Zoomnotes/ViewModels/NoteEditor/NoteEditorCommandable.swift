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

enum NoteChildDetailViewController {
    case image(ImageDetailViewController, id: NoteImageID)
    case sublevel(NoteViewController, id: NoteLevelID)
}

protocol NoteChildProtocol {
    func resize(using editor: NoteEditorProtocol, to: CGRect)
    func move(using editor: NoteEditorProtocol, to: CGRect)
    func remove(using editor: NoteEditorProtocol)
    func detailViewController(from: UIStoryboard?) -> NoteChildDetailViewController?
}

protocol NoteEditorProtocol {
    func create(id: NoteLevelID, frame: CGRect, preview: UIImage) -> AnyPublisher<Void, Error>
    func create(id: NoteImageID, frame: CGRect, preview: UIImage) -> AnyPublisher<Void, Error>
    func update(drawing: PKDrawing)
    func refresh(image: UIImage)
    func update(id: NoteImageID, annotation: PKDrawing)
    func update(id: NoteImageID, preview: UIImage)
    func move(id: NoteLevelID, to: CGRect)
    func move(id: NoteImageID, to: CGRect)
    func resize(id: NoteLevelID, to: CGRect)
    func resize(id: NoteImageID, to: CGRect)
    func remove(id: NoteImageID)
    func remove(id: NoteLevelID)
    func moveToDrawer(id: NoteLevelID, frame: CGRect)
    func moveToDrawer(id: NoteImageID, frame: CGRect)
    func moveFromDrawer(id: NoteLevelID, frame: CGRect)
    func moveFromDrawer(id: NoteImageID, frame: CGRect)
}
