//
//  NoteModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit
import Combine

enum NoteChildStore: Equatable {
    case level(NoteLevelID)
    case image(NoteImageID)
}

class NoteChildVM: ObservableObject {
    let id: UUID
    let store: NoteChildStore
    @Published var preview: UIImage
    @Published var frame: CGRect

    init(id: UUID,
         preview: UIImage,
         frame: CGRect,
         store: NoteChildStore) {
        self.id = id
        self.store = store
        self.preview = preview
        self.frame = frame
    }
}
