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

class NoteLevelVM: ObservableObject {
    let id: UUID
    @Published var preview: UIImage
    @Published var frame: CGRect

    init(id: UUID, preview: UIImage, frame: CGRect) {
        self.id = id
        self.preview = preview
        self.frame = frame
    }
}
