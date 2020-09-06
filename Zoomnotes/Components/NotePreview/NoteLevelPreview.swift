//
//  NoteLevelPreview.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 19..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import PencilKit

class NoteLevelPreview: UIImageView {
    let note: NoteModel.NoteLevel
    init(for note: NoteModel.NoteLevel) {
        self.note = note
        super.init(frame: note.frame)

        self.backgroundColor = UIColor.white
        self.isUserInteractionEnabled = true

        let darklayer = UIView(frame: CGRect(x: 0,
                                             y: 0,
                                             width: note.frame.width,
                                             height: note.frame.height))
        darklayer.backgroundColor = UIColor.darkGray
        darklayer.layer.opacity = 0.02
        self.addSubview(darklayer)

        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        self.layer.shadowOpacity = 0.1
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    required init?(coder: NSCoder) {
        fatalError("shit sux")
    }
}
