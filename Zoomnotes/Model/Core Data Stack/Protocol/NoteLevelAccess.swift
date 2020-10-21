//
//  NoteLevelAccess.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit
import Combine
import UIKit

protocol NoteLevelAccess {
    func append(level description: NoteLevelDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func append(image description: NoteImageDescription, to parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func remove(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func remove(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func restore(level id: NoteLevelID, to parent: NoteLevelID) -> AnyPublisher<SublevelDescription, Error>
    func restore(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<SubImageDescription, Error>
    func emptyTrash() -> AnyPublisher<Void, Error>
    func read(level id: NoteLevelID) -> AnyPublisher<NoteLevelDescription?, Error>
    func read(image id: NoteImageID) -> AnyPublisher<NoteImageDescription?, Error>
    func moveToDrawer(image id: NoteImageID, from parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func moveToDrawer(level id: NoteLevelID, from parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func moveFromDrawer(image id: NoteImageID, to parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func moveFromDrawer(level id: NoteLevelID, to parent: NoteLevelID) -> AnyPublisher<Void, Error>
    func update(drawing: PKDrawing, for id: NoteLevelID) -> AnyPublisher<Void, Error>
    func update(preview: UIImage, for id: NoteLevelID) -> AnyPublisher<Void, Error>
    func update(preview: UIImage, image: NoteImageID) -> AnyPublisher<Void, Error>
    func update(frame: CGRect, for id: NoteLevelID) -> AnyPublisher<Void, Error>
    func update(frame: CGRect, image: NoteImageID) -> AnyPublisher<Void, Error>
    func update(annotation: PKDrawing, image: NoteImageID) -> AnyPublisher<Void, Error>
}
