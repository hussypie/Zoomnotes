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
    case move(NoteModel.NoteLevel, from: CGRect, to: CGRect)
    case remove(NoteModel.NoteLevel)
    case create(NoteModel.NoteLevel)
    case resize(NoteModel.NoteLevel, from: CGRect, to: CGRect)
    case update(PKDrawing)
    case refresh(CodableImage)
    case moveToDrawer(NoteModel.NoteLevel, frame: CGRect)
    case moveFromDrawer(NoteModel.NoteLevel, frame: CGRect)
}

protocol NoteEditorCommandable {
    func process(_ command: NoteEditorCommand)
}
