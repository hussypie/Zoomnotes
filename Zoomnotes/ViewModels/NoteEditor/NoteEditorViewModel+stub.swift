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
    static func stub(sublevels: [NoteChildVM],
                     access: NoteLevelAccess,
                     onUpdateName: @escaping (String) -> Void
    ) -> NoteEditorViewModel {
        return NoteEditorViewModel(id: ID(UUID()),
                                   title: "Note",
                                   sublevels: sublevels,
                                   drawer: [],
                                   drawing: PKDrawing(),
                                   access: access,
                                   onUpdateName: onUpdateName)
    }
}
