//
//  NoteEditorCommandable.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 20..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

enum NoteEditorCommand {
    case move(NoteLevelVM, from: CGRect, to: CGRect)
    case remove(NoteLevelVM)
    case create(NoteLevelVM)
    case resize(NoteLevelVM, from: CGRect, to: CGRect)
    case update(PKDrawing)
    case refresh(CodableImage)
    case moveToDrawer(NoteLevelVM, frame: CGRect)
    case moveFromDrawer(NoteLevelVM, frame: CGRect)
}

protocol NoteEditorCommandable {
    func process(_ command: NoteEditorCommand)
}
