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
    func update(drawing: PKDrawing) -> AnyPublisher<Void, Error>
    func refresh(image: UIImage) -> AnyPublisher<Void, Error>
    func update(id: NoteImageID, annotation: PKDrawing) -> AnyPublisher<Void, Error>
    func update(id: NoteImageID, preview: UIImage) -> AnyPublisher<Void, Error>
    func move(child: NoteChildVM, to: CGRect) -> AnyPublisher<Void, Error>
    func resize(child: NoteChildVM, to: CGRect) -> AnyPublisher<Void, Error>
    func remove(child: NoteChildVM) -> AnyPublisher<Void, Error>
    func restore(child: NoteChildVM) -> AnyPublisher<Void, Error>
    func moveToDrawer(child: NoteChildVM, frame: CGRect) -> AnyPublisher<Void, Error>
    func moveFromDrawer(child: NoteChildVM, frame: CGRect) -> AnyPublisher<Void, Error>
}
