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
    case createLevel(NoteChildVM)
    case createImage(NoteChildVM)
    case moveLevel(NoteChildVM, from: CGRect, to: CGRect)
    case moveImage(NoteChildVM, from: CGRect, to: CGRect)
    case removeLevel(NoteChildVM)
    case removeImage(NoteChildVM)
    case resizeLevel(NoteChildVM, from: CGRect, to: CGRect)
    case resizeImage(NoteChildVM, from: CGRect, to: CGRect)
    case update(PKDrawing)
    case refresh(UIImage)
    case moveToDrawer(NoteChildVM, frame: CGRect)
    case moveFromDrawer(NoteChildVM, frame: CGRect)
}

protocol NoteEditorCommandable {
    func process(_ command: NoteEditorCommand)
}
