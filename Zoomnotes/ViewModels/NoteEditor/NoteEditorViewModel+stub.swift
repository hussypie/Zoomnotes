//
//  NoteEditorViewModel+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import PencilKit

extension NoteEditorViewModel {
    static func stub(sublevels: [UUID: NoteLevelVM],
                     drawer: [UUID: NoteLevelVM],
                     access: NoteLevelAccess,
                     onUpdateName: @escaping (String) -> Void
    ) -> NoteEditorViewModel {
        return NoteEditorViewModel(id: UUID(),
                                   title: "Note",
                                   sublevels: sublevels,
                                   drawing: PKDrawing(),
                                   access: access,
                                   drawer: drawer,
                                   onUpdateName: onUpdateName)
    }
}
